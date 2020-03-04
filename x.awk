#!/usr/bin/awk -f

function err(j, m) {
    print "error:" NR ":" j["pos"] ": " m > "/dev/stderr";
    exit 3;
}

function nextch(j) {
    if (j["c"] == "")
        return "";

    j["c"] = substr(j["s"], j["pos"]+1, 1);
    if (j["c"] == "")
        return "";

    ++j["pos"];
    return j["c"];
}

function eat(j, c) {
    if (j["c"] == c) {
        nextch(j);
        return 1;
    } else {
        return 0;
    }
}

function expct(j, t) {
    if (!eat(j, t))
        err(j, "expect '" t "'");
}

function ishex(c) {
    return c >= "0" && c <= "9" || c >= "a" && c <= "f" ||
                                   c >= "A" && c <= "F";
}

function escape(j,      c, i, u) {
    c = nextch(j);
    if (c in esc) {
        return "\\" c;
    } else if (c == "u") {
        u = "\\u";
        for (i = 0; i < 4; i++) {
            c = nextch(j);
            if (!ishex(c))
                err(j, "incompleted unicode sequence");
            u = u c;
        }
        return u;
    }
    err(j, "unexpected escape sequence: \\" c);
}

function str(j,     c, v) {
    v = "";
    # " is already consumed
    for (c = j["c"]; c != "\""; c = nextch(j)) {
        if (c == "")
            err(j, "unterminated string");
        else if (c in bad)
            err(j, "bad binary character inside a string: " bad[c]);
        else if (c == "\\")
            v = v escape(j);
        else
            v = v c;
    }
    nextch(j);
    return v;
}

function space(j,       c) {
    for (c = j["c"]; c == " " || c == "\t"; c = nextch(j))
        ;
}

function isdig(c) {
    return c >= "0" && c <= "9";
}

function frac_exp(j,    c, f) {
    c = j["c"];
    f = "";
    if (c == ".") {
        f = f c;
        c = nextch(j);
        if (!isdig(c))
            err(j, "expected fraction");
        for (; isdig(c); c = nextch(j))
            f = f c;
    }

    if (c == "e" || c == "E") {
        f = f c;
        c = nextch(j);
        if (c == "+" || c == "-") {
            f = f c;
            c = nextch(j);
        }
        if (!isdig(c))
            err(j, "expected exponent");
        for (; isdig(c); c = nextch(j))
            f = f c;
    }
    return f;
}

function num(j, c,    n) {
    n = "";
    if (c == "-") {
        n = "-";
        c = j["c"];
        if (!isdig(c))
            err(j, "expected number");
        nextch(j);
    }

    n = n c;
    # leading zeros are not allowed for numbers except 0.123
    if (c != "0")
        for (c = j["c"]; isdig(c); c = nextch(j))
            n = n c;

    return n frac_exp(j);
}

function ident(j, c) {
    if (c == "t" && !(eat(j, "r") && eat(j, "u") && eat(j, "e")))
        err(j, "'true' expected");
    else if (c == "f" && !(eat(j, "a") && eat(j, "l") && eat(j, "s") && eat(j, "e")))
        err(j, "'false' expected");
    else if (c == "n" && !(eat(j, "u") && eat(j, "l") && eat(j, "l")))
        err(j, "'null' expected");
    return c == "t" ? "true" : c == "f" ? "false" : "null";
}

function eatdig(j) {
    if (isdig(j["c"])) {
        nextch(j);
        return 1;
    } else {
        return 0;
    }
}

function print_sp(nl, nest) {
    printf("%s%*s", nl ? "\n" : "", nest * sp, "");
}

function j_parse(j, src,      s, c, n) {
    j["s"] = src;
    j["c"] = " ";
    j["pos"] = 0;

    s = j["state"];
    n = j["nest"];

    for (;;) {
        space(j);
        c = j["c"];
        # eol
        if (c == "") {
            j["state"] = s;
            j["nest"] = n;
            return 0;
        }

        if (s == S_ARR || s == S_ARRTL ||
            s == S_OBJ || s == S_OBJTL) {
            c = (s == S_ARR || s == S_ARRTL) ? "]" : "}";
            if (eat(j, c)) {
                delete j[n--];
                print_sp(s == S_ARRTL || s == S_OBJTL, n);
                printf(c);
                if (!n)
                    break;
                else
                    s = j[n] == "{" ? S_OBJTL : S_ARRTL;
            } else {
                if (s == S_ARRTL || s == S_OBJTL) {
                    expct(j, ",");
                    print ",";
                }

                print_sp(0, n);
                if (s == S_ARR || s == S_ARRTL)
                    s = S_VAL;
                else
                    s = S_OBJKEY;
            }
        } else if (s == S_OBJKEY) {
            expct(j, "\"");
            j["key"] = str(j);
            s = S_OBJCOL;
        } else if (s == S_OBJCOL) {
            expct(j, ":");
            printf("\"%s\": ", j["key"]);
            s = S_VAL;
        } else if (s == S_VAL) {
            if (eat(j, "[") || eat(j, "{")) {
                s = c == "{" ? S_OBJ : S_ARR;
                print c;
                j[++n] = c;
            } else {
                # atom types
                if (eat(j, "\""))
                    printf("\"%s\"", str(j));
                else if (eat(j, "-") || eatdig(j))
                    printf(num(j, c));
                else if (eat(j, "t") || eat(j, "f") || eat(j, "n"))
                    printf(ident(j, c));
                else
                    err(j, "unexpected " (c == "" ? "eof" : "character: " c));
                if (!n)
                    break;
                else
                    s = j[n] == "{" ? S_OBJTL : S_ARRTL;
            }
        } else {
            err(j, "unknown state " s);
        }
    }

    j["state"] = S_END;
    return 1;
}

function j_init(     n, a, i) {
    # iterative states
    S_ARR = 1; S_ARRTL = 2; S_OBJ = 3; S_OBJKEY = 4;
    S_OBJCOL = 5; S_OBJTL = 6; S_VAL = 7; S_END = 8;

    n = split("\",\\,/,b,f,n,r,t", a, ",")
    for (i = 1; i <= n; i++)
        esc[a[i]] = "";
    # binary chars lookup
    for (i = 0; i < 32; i++)
        bad[sprintf("%c", i)] = i;
}

function j_obj(j) {
    j["nest"] = 0;
    j["state"] = S_VAL;
    j["key"] = "";
}

BEGIN {
    # don't need fields
    FS = "\n";
    sp = "INDENT" in ENVIRON && ENVIRON["INDENT"] > 0 ? ENVIRON["INDENT"] : 4;
    j_init();
    j_obj(obj);

    while (getline line > 0)
        if (j_parse(obj, line))
            exit 0;

    err(obj, "incomplete file");
}

#END {
#    print "THE END" >> "/tmp/awk.log";
#    system("sleep 10000");
#}


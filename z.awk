#!/usr/bin/awk -f

function j_new(j, p, t, v,       i) {
    #if (!("id" in j))
    #    j["id"] = 0;
    i = ++j["id"];
    j[i, "p"] = p;
    j[i] = t;
    j[i, ""] = v;
    return i;
}

function j_put_a(j, i, v,      n) {
    #if (!((i, "sz") in j))
    #    j[i, "sz"] = 0;
    n = ++j[i, "sz"];
    j[i, n] = v;
    return n;
}

function j_put_kv(j, i, k, v,       n) {
    n = j_put_a(j, i, k);
    j[i, n, ""] = v;
    # fast key lookup to find value in array [i, n, k]
    j[i, "", k] = n;
    return n;
}

function warn(j, m) {
    print "warning:" j["lineno"] ":" j["pos"] ": " m > "/dev/stderr";
}

function err(j, m) {
    print "error:" j["lineno"] ":" j["pos"] ": " m > "/dev/stderr";
    exit 3;
}

function check_k(j, i, k) {
    if ((i, "", k) in j)
        warn(j, "duplicated key '" k "'");
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

function j_parse_s(j, p) {
    return j_new(j, p, T_S, str(j));
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
            err(j, "epxected fraction");
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
            err(j, "epxected exponent");
        for (; isdig(c); c = nextch(j))
            f = f c;
    }
    return f;
}

function j_parse_n(j, p, c,    n) {
    n = "";
    if (c == "-") {
        n = "-";
        c = j["c"];
        if (!isdig(c))
            err(j, "epxected number");
        nextch(j);
    }

    n = n c;
    # leading zeros are not allowed for numbers except 0.123
    if (c != "0")
        for (c = j["c"]; isdig(c); c = nextch(j))
            n = n c;

    return j_new(j, p, T_N, n frac_exp(j));
}

function j_parse_i(j, p, c) {
    if (c == "t" && !(eat(j, "r") && eat(j, "u") && eat(j, "e")))
        err(j, "'true' epxected");
    else if (c == "f" && !(eat(j, "a") && eat(j, "l") && eat(j, "s") && eat(j, "e")))
        err(j, "'false' epxected");
    else if (c == "n" && !(eat(j, "u") && eat(j, "l") && eat(j, "l")))
        err(j, "'null' epxected");
    return j_new(j, p, c == "t" ? T_T : c == "f" ? T_F : T_Z, "");
}

function eatdig(j) {
    if (isdig(j["c"])) {
        nextch(j);
        return 1;
    } else {
        return 0;
    }
}

function j_put_p(j, i,    p, t) {
    p = j[i, "p"];
    t = j[p];
    if (t == T_A)
        j_put_a(j, p, i);
    else if (t == T_O)
        j_put_kv(j, p, j[p, "k"], i);
    else
        exit 5;
}

function j_parse(j,     p, s, i, c) {
    i = 0;
    p = j["par"];
    s = j["state"];

    for (;;) {
        space(j);
        c = j["c"];
        # eol
        if (c == "") {
            j["par"] = p;
            j["state"] = s;
            return 0;
        }

        if (s == S_ARR || s == S_ARRTL ||
            s == S_OBJ || s == S_OBJTL) {
            c = (s == S_ARR || s == S_ARRTL) ? "]" : "}";
            if (eat(j, c)) {
                i = p;
                if (s == S_OBJ || s == S_OBJTL)
                    delete j[i, "k"];
                p = j[i, "p"];
                if (!p)
                    break;
                j_put_p(j, i);
                s = j[p] == T_O ? S_OBJTL : S_ARRTL;
            } else {
                if (s == S_ARRTL || s == S_OBJTL)
                    expct(j, ",");
                if (s == S_ARR || s == S_ARRTL)
                    s = S_VAL;
                else
                    s = S_OBJKEY;
            }
        } else if (s == S_OBJKEY) {
            expct(j, "\"");
            j[p, "k"] = str(j);
            check_k(j, p, j[p, "k"]);
            s = S_OBJCOL;
        } else if (s == S_OBJCOL) {
            expct(j, ":");
            s = S_VAL;
        } else if (s == S_VAL) {
            if (eat(j, "[")) {
                p = i = j_new(j, p, T_A, "");
                s = S_ARR;
            } else if (eat(j, "{")) {
                p = i = j_new(j, p, T_O, "");
                j[i, "k"] = "";
                s = S_OBJ;
            } else {
                # atom types
                if (eat(j, "\"")) {
                    i = j_parse_s(j, p);
                } else if (eat(j, "-") || eatdig(j)) {
                    i = j_parse_n(j, p, c);
                } else if (eat(j, "t") || eat(j, "f") || eat(j, "n")) {
                    i = j_parse_i(j, p, c);
                } else {
                    err(j, "unexpected " (c == "" ? "eof" : "character: " c));
                }
                if (!p)
                    break;
                j_put_p(j, i);
                s = j[p] == T_O ? S_OBJTL : S_ARRTL;
            }
        } else {
            err(j, "unknown state " s);
        }
    }

    j["state"] = S_END;
    return i;
}

function print_sp(j, nl) {
    printf("%s%*s", nl ? "\n" : "", j["nest"] * sp, "");
}

function j_print(j, i,     s, e, t, n) {
    while (i) {
        t = j[i];
        if (t == T_O || t == T_A) {
            if (t == T_O) {
                s = "{"; e = "}";
            } else {
                s = "["; e = "]"; 
            }

            if (!((i, "n") in j)) {
                # open array or object
                print s;
                j["nest"] += 1;
                j[i, "n"] = 0; # iteration state
            }

            n = j[i, "n"];
            if (n < j[i, "sz"]) {
                if (n > 0)
                    print ",";
                j[i, "n"] = ++n;
                print_sp(j, 0);
                if (t == T_O) {
                    printf("\"%s\": ", j[i, n]);
                    i = j[i, n, ""];
                } else {
                    i = j[i, n];
                }
            } else {
                # close array or object
                delete j[i, "n"];
                j["nest"] -= 1;
                print_sp(j, n > 0);
                printf(e);
                i = j[i, "p"];
            }
        } else {
            if (t == T_S)
                printf("\"%s\"", j[i, ""]);
            else if (t == T_N)
                printf("%s", j[i, ""]);
            else if (j[i] == T_T)
                printf("true");
            else if (j[i] == T_F)
                printf("false");
            else if (j[i] == T_Z)
                printf("null");
            i = j[i, "p"];
        }
    }
}

function j_flat_a(j, a,    i) {
    if ((a, "sz") in j) {
        printf("[%d, \"sz\"] = %d\n", a, j[a, "sz"]);
        for (i = 1; i <= j[a, "sz"]; i++)
            printf("[%d, %d] = %s\n", a, i, j[a, i]);
    }
}

function j_flat_o(j, o,     i, k) {
    if ((o, "sz") in j) {
        printf("[%d, \"sz\"] = %d\n", o, j[o, "sz"]);
        for (i = 1; i <= j[o, "sz"]; i++) {
            k = j[o, i];
            printf("[%d, %d] = \"%s\"\n", o, i, k);
            printf("[%d, %d, \"\"] = %s\n", o, i, j[o, i, ""]);
        }
    }
}

function j_flat_s(j, s) {
    printf("[%d, \"\"] = \"%s\"\n", s, j[s, ""]);
}

function j_flat_n(j, n) {
    printf("[%d, \"\"] = %s\n", n, j[n, ""]);
}

function j_flat(j,     i) {
    printf("[\"id\"] = %d\n", j["id"]);
    for (i = 1; i <= j["id"]; i++) {
        printf("[%d] = %s\n", i, t2s[j[i]]);
        if (j[i] == T_A)
            j_flat_a(j, i);
        else if (j[i] == T_O)
            j_flat_o(j, i)
        else if (j[i] == T_S)
            j_flat_s(j, i)
        else if (j[i] == T_N)
            j_flat_n(j, i)
    }
}

function json_init(j,     n, a, i) {
    # iterative states
    S_ARR = 1; S_ARRTL = 2; S_OBJ = 3; S_OBJKEY = 4;
    S_OBJCOL = 5; S_OBJTL = 6; S_VAL = 7; S_END = 8;
    # array, object, string, number, true. false, null (Z)
    T_A = 1; T_O = 2; T_S = 3; T_N = 4; T_T = 5; T_F = 6; T_Z = 7;

    split("arr,obj,str,num,true,false,null", t2s, ",")
    n = split("\",\\,/,b,f,n,r,t", a, ",")
    for (i = 1; i <= n; i++)
        esc[a[i]] = "";
    # binary chars lookup
    for (i = 0; i < 32; i++)
        bad[sprintf("%c", i)] = i;
    j["par"] = 0;
    j["nest"] = 0;
    j["state"] = S_VAL;
    j["lineno"] = 0;
}

function json_parse(j, s) {
    j["s"] = s;
    j["c"] = " ";
    j["pos"] = 0;
    return j_parse(j);
}

function json_print(j) {
    if ("id" in j && "1" in j) {
        j_print(j, 1);
        print "";
    }
}

function json_flat(j) {
    if ("id" in j)
        j_flat(j);
}

BEGIN {
    # don't need fields
    FS = "\n";
    sp = "INDENT" in ENVIRON && ENVIRON["INDENT"] > 0 ? ENVIRON["INDENT"] : 4;
    json_init(json);
}

{
    json["lineno"] += 1;
    if (json_parse(json, $0)) {
        "FLAT" in ENVIRON ? json_flat(json) : json_print(json);
        exit 0;
    }
}

#END {
#    print "THE END" >> "/tmp/awk.log";
#    system("sleep 10000");
#}


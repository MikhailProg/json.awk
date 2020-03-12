#!/usr/bin/awk -f

function j_new(j, t, v,       i) {
    i = ++j["id"];
    j[i] = t;
    if (t == T_O || t == T_A)
        j[i, "sz"] = 0;
    j[i, ""] = v;
    return i;
}

function j_put_a(j, i, v,      n) {
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
    print "warning:" NR ":" j["pos"] ": " m > "/dev/stderr";
}

function err(j, m) {
    print "error:" NR ":" j["pos"] ": " m > "/dev/stderr";
    exit 3;
}

function check_k(j, i, k) {
    if ((i, "", k) in j)
        warn(j, "duplicated key '" k "'");
}

function nextchL(j) {
    if (j["s"] == "")
        return "";
    j["c"] = substr(j["s"], j["pos"]+1, 1);
    if (j["c"] == "")
        return "";
    ++j["pos"];
    return j["c"];
}

function nextch(j) {
    nextchL(j);
    while (j["c"] == "") {
        if (getline j["s"] <= 0)
            return "";
        j["pos"] = 0;
        nextchL(j);
    }
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
    for (c = j["c"]; c != "\""; c = nextchL(j)) {
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

function j_parse_kv(j, i,       k) {
    space(j);
    expct(j, "\"");
    k = str(j);
    check_k(j, i, k);
    space(j);
    expct(j, ":");
    space(j);
    j_put_kv(j, i, k, j_parse(j));
}

function j_parse_o(j,       i) {
    i = j_new(j, T_O, "");
    space(j);
    if (!eat(j, "}")) {
        j_parse_kv(j, i);
        space(j);

        while (eat(j, ",")) {
            j_parse_kv(j, i);
            space(j);
        }
        expct(j, "}");
    }
    return i;
}

function j_parse_a(j,       i) {
    i = j_new(j, T_A, "");
    space(j);
    if (!eat(j, "]")) {
        j_put_a(j, i, j_parse(j));
        space(j);

        while (eat(j, ",")) {
            j_put_a(j, i, j_parse(j));
            space(j);
        }
        expct(j, "]");
    }
    return i;
}

function j_parse_s(j) {
    return j_new(j, T_S, str(j));
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

function num(j, c,    n) {
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
        for (c = j["c"]; isdig(c); c = nextchL(j))
            n = n c;

    return n frac_exp(j);
}

function j_parse_n(j, c) {
    return j_new(j, T_N, num(j, c));
}

function j_parse_i(j, c) {
    if (c == "t" && !(eat(j, "r") && eat(j, "u") && eat(j, "e")))
        err(j, "'true' epxected");
    else if (c == "f" && !(eat(j, "a") && eat(j, "l") && eat(j, "s") && eat(j, "e")))
        err(j, "'false' epxected");
    else if (c == "n" && !(eat(j, "u") && eat(j, "l") && eat(j, "l")))
        err(j, "'null' epxected");
    return j_new(j, c == "t" ? T_T : c == "f" ? T_F : T_Z, "");
}

function eatdig(j) {
    if (isdig(j["c"])) {
        nextch(j);
        return 1;
    } else {
        return 0;
    }
}

function j_parse(j,     c) {
    space(j);
    c = j["c"];
    if (eat(j, "["))
        return j_parse_a(j);
    else if (eat(j, "{"))
        return j_parse_o(j);
    else if (eat(j, "\""))
        return j_parse_s(j);
    else if (eat(j, "-") || eatdig(j))
        return j_parse_n(j, c);
    else if (eat(j, "t") || eat(j, "f") || eat(j, "n"))
        return j_parse_i(j, c);
    else
        err(j, "unexpected " (c == "" ? "eof" : "character: " c));
}

function print_sp(j, nl) {
    printf("%s%*s", nl ? "\n" : "", j["nest"] * sp, "");
}

function j_print_a(j, a,       i) {
    printf("[\n");
    j["nest"] += 1;

    for (i = 1; i <= j[a, "sz"]; i++) {
        print_sp(j, 0);
        j_print(j, j[a, i])
        if (i != j[a, "sz"])
            print ",";
    }

    j["nest"] -= 1;
    print_sp(j, j[a, "sz"] > 0);
    printf("]");
}

function j_print_o(j, o,       i, k) {
    printf("{\n");
    j["nest"] += 1;

    for (i = 1; i <= j[o, "sz"]; i++) {
        k = j[o, i];
        print_sp(j, 0);
        printf("\"%s\": ", k);
        j_print(j, j[o, i, ""]);
        if (i != j[o, "sz"])
            print ",";
    }

    j["nest"] -= 1;
    print_sp(j, j[o, "sz"] > 0);
    printf("}");
}

function j_print(j, i) {
    if (j[i] == T_A)
        j_print_a(j, i)
    else if (j[i] == T_O)
        j_print_o(j, i)
    else if (j[i] == T_S)
        printf("\"%s\"", j[i, ""]);
    else if (j[i] == T_N)
        printf("%s", j[i, ""]);
    else if (j[i] == T_T)
        printf("true");
    else if (j[i] == T_F)
        printf("false");
    else if (j[i] == T_Z)
        printf("null");
}

function j_flat(j,     i, k) {
    printf("[\"id\"] = %d\n", j["id"]);
    for (i = 1; i <= j["id"]; i++) {
        printf("[%d] = %s\n", i, t2s[j[i]]);
        if (j[i] == T_A) {
            printf("[%d, \"sz\"] = %d\n", i, j[i, "sz"]);
            for (k = 1; k <= j[i, "sz"]; k++)
                printf("[%d, %d] = %s\n", i, k, j[i, k]);
        } else if (j[i] == T_O) {
            printf("[%d, \"sz\"] = %d\n", i, j[i, "sz"]);
            for (k = 1; k <= j[i, "sz"]; k++) {
                printf("[%d, %d] = \"%s\"\n", i, k, j[i, k]);
                printf("[%d, %d, \"\"] = %s\n", i, k, j[i, k, ""]);
            }
        } else if (j[i] == T_S) {
            printf("[%d, \"\"] = \"%s\"\n", i, j[i, ""]);
        } else if (j[i] == T_N) {
            printf("[%d, \"\"] = %s\n", i, j[i, ""]);
        }
    }
}

function j_init(     n, a, i) {
    # array, object, string, number, true. false, null (Z)
    T_A = 1; T_O = 2; T_S = 3; T_N = 4; T_T = 5; T_F = 6; T_Z = 7;

    split("arr,obj,str,num,true,false,null", t2s, ",");
    n = split("\",\\,/,b,f,n,r,t", a, ",")
    for (i = 1; i <= n; i++)
        esc[a[i]] = "";
    # binary chars lookup
    for (i = 0; i < 32; i++)
        bad[sprintf("%c", i)] = i;
}

function j_obj(j, s) {
    j["id"] = 0;
    j["nest"] = 0;
    j["pos"] = 0;
    j["s"] = "";
    j["c"] = "";
    nextch(j);
}

BEGIN {
    # don't need fields
    FS = "\n";
    sp = "INDENT" in ENVIRON && ENVIRON["INDENT"] > 0 ? ENVIRON["INDENT"] : 4;
    j_init();
    j_obj(obj);

    id = j_parse(obj);
    if (id) {
        "FLAT" in ENVIRON ? j_flat(obj) : j_print(obj, id);
        exit 0;
    }

    err(obj, "incomplete file");
}


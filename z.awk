#!/usr/bin/awk -f

function j_new(j, t, v,       i) {
    if (!("id" in j))
        j["id"] = 0;
    i = ++j["id"];
    j[i] = t;
    j[i, ""] = v;
    return i;
}

function j_put_at(j, i, v,      n) {
    # allocate the next index if it's not provided
    if (!((i, "sz") in j))
        j[i, "sz"] = 0;
    n = ++j[i, "sz"];
    j[i, n] = v;
    return n;
}

function j_put_kv(j, i, k, v,		n) {
    n = j_put_at(j, i, k);
    j[i, n, ""] = v;
    # fast key lookup to find value in array [i, n, k]
    j[i, 0, k] = n;
    return n;
}

function warn(j, m) {
    print "warning:" j["lineno"] ":" j["lpos"] ": " m > "/dev/stderr";
}

function err(j, m) {
    print "error:" j["lineno"] ":" j["lpos"] ": " m > "/dev/stderr";
    exit 3;
}

function check_k(j, i, k) {
    if ((i, 0, k) in j)
        warn(j, "duplicated key '" k "'");
}

function nextch(j) {
    j["c"] = substr(j["s"], j["spos"]+1, 1);
    ++j["spos"];
    ++j["lpos"];
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
    c = j["c"];
    while (c == " " || c == "\t" || c == "\n" || c == "\r") {
        if (c == "\n") {
            ++j["lineno"];
            j["lpos"] = 0;
        }
        c = nextch(j);
    }
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
    i = j_new(j, "o", "");
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
    i = j_new(j, "a", "");
    space(j);
    if (!eat(j, "]")) {
        j_put_at(j, i, j_parse(j));
        space(j);

        while (eat(j, ",")) {
            j_put_at(j, i, j_parse(j));
            space(j);
        }
        expct(j, "]");
    }
    return i;
}

function j_parse_s(j) {
    return j_new(j, "s", str(j));
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

function j_parse_n(j, c,    n) {
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

    return j_new(j, "n", n frac_exp(j));
}

function j_parse_i(j, c) {
    if (c == "t" && !(eat(j, "r") && eat(j, "u") && eat(j, "e")))
        err(j, "'true' epxected");
    else if (c == "f" && !(eat(j, "a") && eat(j, "l") && eat(j, "s") && eat(j, "e")))
        err(j, "'false' epxected");
    else if (c == "n" && !(eat(j, "u") && eat(j, "l") && eat(j, "l")))
        err(j, "'null' epxected");
    return j_new(j, c == "n" ? "z" : c, "");
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
        err(j, "unexpected " (c == "" ? "eof" : "character"));
}

function print_sp(j, nl) {
    printf("%s%*s", nl ? "\n" : "", j["nest"] * sp, "");
}

function j_print_s(j, s) {
    printf("\"%s\"", j[s, ""]);
}

function j_print_n(j, n) {
    printf("%s", j[n, ""]);
}

function j_print_a(j, a,       i) {
    printf("[\n");
    j["nest"] += 1;

    if ((a, "sz") in j) {
        for (i = 1; i <= j[a, "sz"]; i++) {
            print_sp(j, 0);
            j_print(j, j[a, i])
            if (i != j[a, "sz"])
                print ",";
        }
    }

    j["nest"] -= 1;
    print_sp(j, (a, "sz") in j);
    printf("]");
}

function j_print_o(j, o,       i, k) {
    printf("{\n");
    j["nest"] += 1;

    if ((o, "sz") in j) {
        for (i = 1; i <= j[o, "sz"]; i++) {
            k = j[o, i];
            print_sp(j, 0);
            printf("\"%s\": ", k);
            j_print(j, j[o, i, ""]);
            if (i != j[o, "sz"])
                print ",";
        }
    }

    j["nest"] -= 1;
    print_sp(j, (o, "sz") in j);
    printf("}");
}

function j_print(j, i) {
    if (j[i] == "a")
        j_print_a(j, i)
    else if (j[i] == "o")
        j_print_o(j, i)
    else if (j[i] == "s")
        j_print_s(j, i)
    else if (j[i] == "n")
        j_print_n(j, i)
    else if (j[i] == "t")
        printf("true");
    else if (j[i] == "f")
        printf("false");
    else if (j[i] == "z")
        printf("null");
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
        printf("[%d] = \"%s\"\n", i, j[i]);
        if (j[i] == "a")
            j_flat_a(j, i);
        else if (j[i] == "o")
            j_flat_o(j, i)
        else if (j[i] == "s")
            j_flat_s(j, i)
        else if (j[i] == "n")
            j_flat_n(j, i)
    }
}

function json_init(     n, a, i) {
    n = split("\",\\,/,b,f,n,r,t", a, ",")
    for (i = 1; i <= n; i++)
        esc[a[i]] = "";
    # binary chars lookup
    for (i = 0; i < 32; i++)
        bad[sprintf("%c", i)] = i;
}

function json_parse(j, s) {
    j["s"] = s;
    j["c"] = " ";
    j["spos"] = 0;
    j["lpos"] = 0;
    j["nest"] = 0;
    j["lineno"] = 1;
    return j_parse(j);
}

function json_print(j) {
    if ("id" in j && "1" in j)
        j_print(j, 1);
}

function json_flat(j) {
    if ("id" in j)
        j_flat(j);
}

BEGIN {
    sp = "NEST" in ENVIRON && ENVIRON["NEST"] > 0 ? ENVIRON["NEST"] : 4;
    getline source;
}

{
    source = source "\n" $0;
}

END {
    json_init();
    json_parse(json, source);
    "FLAT" in ENVIRON ? json_flat(json) : json_print(json);
}


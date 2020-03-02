# JSON AWK beautifier

To represent JSON tree structure the beautifier doesn't use gawk multidimensional array extension. Instead the implementation utilizes "classic" multidimensional array like `array[expr1,expr2]` which is a syntactic sugar and is equivalent to onedimensional `array[expr1 SUBSEP  expr2]` where `expr1 SUBSEP expr2` is string concatenation expression.

Even if now gawk is presented everywhere the challenge was to run the beautifier within any awk implementation. I even tried nawk from [The Heirloom Toolchest](http://heirloom.sourceforge.net/tools.html) and it works fine but sure not very fast.

The beautifier doesn't use recursion, the parser and the printer are iterative (there is a recursive version in `recursive` branch). A recursive parser needs a whole json file in advance before start parsing. The main recursive parser disadvantage is that it is difficult (if possible at all for AWK runtime) to keep the parser state (deep nesting stack) and then to restore it on the next data chunk. The iterative approach works much better, the current parser is lineoriented, it reads input line by line and preserves its state between parsing adjoint lines.

The beautifier is also a verifier since it follows RFC.

`x.sh` is online beautifier it checks JSON string, number, grammar rules and prints content immediately.

`z.sh` stores the parsed object and just when it is fully parsed prints it. 

Run beautifiers:

```
$ ./x.awk < ./z.json
...
$ ./z.awk < ./z.json
...

```

## Test awks

mawk 1.3.4

gawk 4.1.4

nawk [The Heirloom Toolchest](http://heirloom.sourcefoge.net/tools.html)

All awks produce the same output:

```
$ xawk -f ./z.awk <./large-file.json >/tmp/xawk.log
```

The following command is used to test awks:

```
$ time xawk -f ./z.awk <./large-file.json >/dev/null
```

CPU: Intel i7-7700

Result for `x.sh`:

|      | gawk  | mawk  | nawk   |
| ---  | ---   | ---   | ---    |
| Time | 15s   | 7.5s  | 4m 47s |


Result for `z.sh`:

|      | gawk  | mawk  | nawk   |
| ---  | ---   | ---   | ---    |
| Time | 19s   | 15s   | 4m 54s |
| RSS  | 871Mb | 367Mb | 536Mb  |


nawk executes the program directly from AST so it's not surprising that it's so slow. gawk and mawk use VM to execute the program but mawk is faster especially in online version. The main gawk drawback is that it consumes a lot of memory.

## Opts

By default each level of nesting is spaced with 4 whitespaces. The formating may be changed by setting INDENT environment variable (number of spaces):

```
$ INDENT=1 ./z.awk < ./z.json
{
 "firstName": "John",
 "lastName": "Smith",
 "isAlive": true,
 "age": 27,
 "address": {
  "streetAddress": "21 2nd Street",
  "city": "New York",
  ...
 "children": [
 ],
 "spouse": null
}

```

Set FLAT environment variable (for `z.sh` only) to see how parsed JSON object is stored in a flat structure:

```
$ FLAT=1 ./z.awk < ./z.json
["id"] = 22
[1] = obj
[1, "sz"] = 8
[1, 1] = "firstName"
...
[20, ""] = "123 456-7890"
[21] = arr
[22] = null
```


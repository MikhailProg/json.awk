# JSON AWK beautifier

To represent JSON tree structure the beautifier doesn't use gawk multidimensional array extension. Instead the implementation utilizes "classic" multidimensional array like `array[expr1,expr2]` which is a syntactic sugar and is equivalent to onedimensional `array[expr1 SUBSEP  expr2]` where `expr1 SUBSEP expr2` is string concatenation expression.

Even if now gawk is presented everywhere the challenge was to run the beautifier within any awk implementation. I even tried nawk from [The Heirloom Toolchest](http://heirloom.sourceforge.net/tools.html) and it works fine but sure not very fast.

The beautifier doesn't use recursion, the parser and the printer are iterative (there is an initial recursive version in `recursive` branch). The parser is lineoriented, it preserves state between parsing adjoint lines.

The beautifier is also a verifier since it follows RFC.

Run beautifier:

```
$ ./z.awk < ./z.json

```

mawk 1.3.4

gawk 4.1.4

nawk [The Heirloom Toolchest](http://heirloom.sourcefoge.net/tools.html)


The following command was used to test awk implementations:

```
$ time xawk -f ./z.awk <./large-file.json >/dev/null
```

|      | gawk  | mawk  | nawk   |
| ---  | ---   | ---   | ---    |
| Time | 19s   | 15s   | 4m 55s |
| RSS  | 871Mb | 367Mb | 536Mb  |

nawk executes the program directly from AST so it's not surprising that it's so slow. gawk and mawk are close to each other, both use VM to execute the program but mawk is slightly faster. The main gawk drawback is that it is very memory greedy.

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

Set FLAT environment variable to see how parsed JSON object is stored in a flat structure:

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


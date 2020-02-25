# JSON AWK beautifier

To represent JSON tree structure the beautifier doesn't use gawk multidimensional array extension. Instead the implementation utilizes "classic" multidimensional array like `array[expr1,expr2]` which is a syntactic sugar and is equivalent to onedimensional `array[expr1 SUBSEP  expr2]` where `expr1 SUBSEP expr2` is string concatenation expression.

Even if now gawk is presented everywhere the challenge was to run the beautifier within any awk implementation. I even tried nawk from [The Heirloom Toolchest](http://heirloom.sourceforge.net/tools.html) and it works fine but sure not very fast.

The beautifier is also a verifier since it follows RFC.

Run beautifier:

```
$ ./z.awk < ./z.json

```

By default each level of nesting is spaced with 4 whitespaces. The formating may be changed by setting NEST environment variable (number of spaces):

```
$ NEST=1 ./z.awk < ./z.json
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
[1] = "o"
[1, "sz"] = 8
[1, 1] = "firstName"
...
[20, ""] = "123 456-7890"
[21] = "a"
[22] = "z"
```


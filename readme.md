`luastatic` takes a single Lua file, embeds it in a C program which uses the Lua C 
API to run it, and builds that program to an executable. The executable runs on systems 
that do not have Lua installed because it contains the Lua interpreter.

## Building
Run `make`.

## Usage
```
$ ./luastatic hello.lua liblua.a
$ ./hello
Hello, world!
```

## TODO
- Support multiple Lua files
- Support linking to Lua binary modules

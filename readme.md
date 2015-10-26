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

# Statically link with the LuaSQLite3 binary module, but 
# dynamicaly link with the SQLite3 shared library
$ ./luastatic sql.lua liblua.a lsqlite3.a -lsqlite3 -pthread
$ ./sql
```

## TODO
- Support multiple Lua files

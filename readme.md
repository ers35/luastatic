`luastatic` takes a single Lua file, embeds it in a C program that uses the Lua C 
API to run it, and builds that program to an executable. The executable runs on systems 
that do not have Lua installed because it contains the Lua interpreter.

## Building
Run `make`.

## Usage
```
$ ./luastatic test/hello.lua liblua.a
$ ./hello
Hello, world!

# Embed a required module by passing it after the main Lua file.
$ ./luastatic test/require1.lua test/require2.lua liblua.a
$ ./require1

# Statically link with the LuaSQLite3 binary module, but 
# dynamicaly link with the SQLite3 shared library
$ ./luastatic test/sql.lua liblua.a test/lsqlite3.a -lsqlite3 -pthread
$ ./sql
```

## TODO
- Support Lua 5.1 and LuaJIT

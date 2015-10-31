`luastatic` takes a single Lua file, embeds it in a C program that uses the Lua C 
API to run it, and builds that program to an executable. The executable runs on systems 
that do not have Lua installed because it contains the Lua interpreter.

## Building
Run `make`.

## Usage
```
# See the test rule in the Makefile for more examples.

$ luastatic hello.lua liblua.a -Ilua-5.2.4/src
$ ./hello
Hello, world!

# Embed a required module by passing it after the main Lua file.
$ luastatic require1.lua require2.lua liblua.a -Ilua-5.2.4/src
$ ./require1

# Statically link with the LuaSQLite3 binary module, but 
# dynamicaly link with the SQLite3 shared library
$ luastatic sql.lua liblua.a lsqlite3.a -lsqlite3 -pthread -Ilua-5.2.4/src
$ ./sql

# Build a more complex project
# https://github.com/ignacio/luagleck
$ luastatic main.lua display.lua logger.lua machine.lua port.lua z80.lua \
  file_format/*.lua machine/spectrum_48.lua opcodes/*.lua liblua.a SDL.a -Ilua-5.3.1/src \
  -lSDL2
$ ./main

```

## TODO
- Support Lua 5.1 and LuaJIT

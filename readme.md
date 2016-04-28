`luastatic` takes one or more Lua source files, embeds them in a C program that uses the 
Lua C API, and builds that program to an executable. The executable runs on systems that 
do not have Lua installed because it contains the Lua interpreter. Lua 5.1, 5.2, 5.3 and 
LuaJIT are supported.

## Building
Run `make` or install from [LuaRocks](http://luarocks.org/modules/ers35/luastatic).

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
# dynamically link with the SQLite3 shared library
$ luastatic sql.lua liblua.a lsqlite3.a -lsqlite3 -pthread -Ilua-5.2.4/src
$ ./sql

# Build a more complex project
# https://github.com/ignacio/luagleck
$ luastatic main.lua display.lua logger.lua machine.lua port.lua z80.lua \
  file_format/*.lua machine/spectrum_48.lua opcodes/*.lua liblua.a SDL.a -Ilua-5.3.1/src \
  -lSDL2
$ ./main
```

See another example at [Lua.Space](http://lua.space/tools/build-a-standalone-executable).

## Arguments
```
luastatic main.lua[1] require.lua[2] liblua.a[3] module.a[4] -Iinclude/lua[5] [6]
[1]: The entry point to the Lua program
[2]: One or more required Lua source files
[3]: The Lua interpreter static library
[4]: One or more static libraries for a required Lua binary module
[5]: The path to the directory containing lua.h
[6]: Additional arguments are passed to the C compiler
```

## Users
- [Omnia](https://github.com/tongson/omnia)

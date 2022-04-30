`luastatic` is a command line tool that builds a standalone executable from a Lua 
program. The executable runs on systems that do not have Lua installed. Lua 5.1, 5.2, 
5.3, 5.4, and LuaJIT are supported.

## Install
Run luastatic.lua or install from [LuaRocks](http://luarocks.org/modules/ers35/luastatic).

## Usage
```
luastatic main.lua[1] require.lua[2] liblua.a[3] library.a[4] -I/include/lua[5] [6]
  [1]: The entry point to the Lua program
  [2]: One or more required Lua source files
  [3]: The path to the Lua interpreter static library
  [4]: One or more static libraries for a required Lua binary module
  [5]: The path to the directory containing lua.h
  [6]: Additional arguments are passed to the C compiler
```

## Examples

### Single Lua file
`luastatic main.lua /usr/lib/x86_64-linux-gnu/liblua5.2.a -I/usr/include/lua5.2`

### Embed library.lua for require("library")
`luastatic main.lua library.lua /usr/lib/x86_64-linux-gnu/liblua5.2.a -I/usr/include/lua5.2`

### C library containing luaopen_()
`luastatic main.lua library.a /usr/lib/x86_64-linux-gnu/liblua5.2.a -I/usr/include/lua5.2`

### Dynamically link with Lua
`luastatic main.lua -llua5.2 -I/usr/include/lua5.2`

### Statically link with musl libc
`CC=musl-gcc luastatic main.lua /usr/lib/x86_64-linux-musl/liblua5.2.a -I/usr/include/lua5.2 -static`

### Cross compile for Windows
`CC=x86_64-w64-mingw32-gcc luastatic main.lua /usr/x86_64-w64-mingw32/lib/liblua5.2.a -I/usr/x86_64-w64-mingw32/include/lua5.2/`

### LuaJIT 2.0.4 on Ubuntu 16.10
`luastatic main.lua /usr/lib/x86_64-linux-gnu/libluajit-5.1.a -I/usr/include/luajit-2.0 -no-pie`

### LuaJIT on macOS
`luastatic main.lua /opt/local/lib/libluajit-5.1.a -I/opt/local/include/luajit-2.0 -pagezero_size 10000 -image_base 100000000`

### Generate the C file but don't compile it
`CC="" luastatic main.lua`

### Lua using Homebrew
```sh
# Install Lua and LuaRocks from Homebrew.
brew install lua luarocks
# Install luastatic from LuaRocks.
luarocks install luastatic
# Build using the Homebrew installation path.
luastatic main.lua $(brew --prefix lua)/lib/liblua.a -I$(brew --prefix lua)/include/lua
```

See another example at [Lua.Space](http://lua.space/tools/build-a-standalone-executable).

## Users
- [MoonTerm](https://github.com/moonsteal/moonterm)
- [Omnia](https://github.com/tongson/omnia)
- [Luacheck](https://github.com/mpeterv/luacheck)
- [Moonscript++](https://github.com/owenkimbrell/Moonscriptxx)
- [d2info](https://github.com/squeek502/d2info)
- [reslister](https://github.com/Metastruct/reslister)
- [aka](https://github.com/bonidjukic/aka)
- [Thenafter](https://github.com/Jictyvoo/Thenafter)
- [luatools](https://github.com/ennorehling/luatools)
- [ttslua-bundle](https://github.com/tjakubo2/ttslua-bundle)
- [Lunar](https://github.com/lunarlang/lunar)
- [yon](https://github.com/polm/yon)

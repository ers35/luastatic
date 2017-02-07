#!/usr/bin/env lua

-- The author disclaims copyright to this source code.

-- The C compiler used to compile and link the generated C source file.
local CC = os.getenv("CC") or "cc"
-- The nm used to determine whether a library is liblua or a Lua binary module.
local NM = os.getenv("NM") or "nm"

local function file_exists(name)
  local f = io.open(name, "r")
  if f then
    f:close()
    return true
  end
  return false
end

--[[
Run a shell command, wait for it to finish, and return a string containing stdout.
--]]
local function shellout(cmd)
  local f = io.popen(cmd)
  local str = f:read("*all")
  local ok = f:close()
  if ok then
    return str
  end
  return nil
end

--[[
Use execute() when stdout isn't needed instead of shellout() because io.popen() does 
not return the status code in Lua 5.1.
--]]
local function execute(cmd)
  local ok = os.execute(cmd)
  return (ok == true or ok == 0)
end

--[[
Create a hex string from the characters of a string.
--]]
local function string_to_hex(characters)
  local hex = {}
  for character in characters:gmatch(".") do
    table.insert(hex, ("0x%02x"):format(string.byte(character)))
  end
  return table.concat(hex, ", ")
end

--[[
/path/to/file.lua -> file.lua
--]]
local function basename(path)
  local name = path:gsub([[(.*[\/])(.*)]], "%2")
  return name
end

local function is_source_file(extension)
  return
    extension == "lua" or
    -- Precompiled chunk.
    extension == "luac"
end

local function is_binary_library(extension)
  return 
    -- Static library.
    extension == "a" or 
    -- Shared library.
    extension == "so" or
    -- Mach-O dynamic library.
    extension == "dylib"
end

-- Required Lua source files.
local lua_source_files = {}
-- Libraries for required Lua binary modules.
local module_library_files = {}
local module_link_libraries = {}
-- Libraries other than Lua binary modules, including liblua.
local dep_library_files = {}
-- Additional arguments are passed to the C compiler.
local otherflags = {}
local link_with_libdl = ""

--[[
Parse command line arguments. main.lua must be the first argument. Static libraries are 
passed to the compiler in the order they appear and may be interspersed with arguments to 
the compiler. Arguments to the compiler are passed to the compiler in the order they 
appear.
--]]
for _, name in ipairs(arg) do
  local extension = name:match("%.(%a+)$")
  if is_source_file(extension) or is_binary_library(extension) then
    if not file_exists(name) then
      io.stderr:write("file does not exist: " .. name .. "\n")
      os.exit(1)
    end

    local info = {}
    info.path = name
    info.basename = basename(info.path)
    info.basename_noextension = info.basename:match("(.+)%.")
    info.dotpath = info.path:gsub("[\\/]", ".")
    info.dotpath_noextension = info.dotpath:match("(.+)%.")
    info.dotpath_underscore = info.dotpath_noextension:gsub("[.-]", "_")

    if is_source_file(extension) then
      table.insert(lua_source_files, info)
    elseif is_binary_library(extension) then
      -- The library is either a Lua module or a library dependency.
      local nmout = shellout(NM .. " " .. info.path)
      if not nmout then
        io.stderr:write("nm not found\n")
        os.exit(1)
      end
      local is_module = false
      if nmout:find("T _?luaL_newstate") then
        if nmout:find("U _?dlopen") then
          --[[
          Link with libdl because liblua was built with support loading shared objects.
          --]]
          link_with_libdl = "-ldl"
        end
      else
        for luaopen in nmout:gmatch("[^dD] _?luaopen_([%a%p%d]+)") do
          local modinfo = {}
          modinfo.path = info.path
          modinfo.dotpath_underscore = luaopen
          modinfo.dotpath = modinfo.dotpath_underscore:gsub("_", ".")
          modinfo.dotpath_noextension = modinfo.dotpath
          is_module = true
          table.insert(module_library_files, modinfo)
        end
      end
      if is_module then
        table.insert(module_link_libraries, info.path)
      else
        table.insert(dep_library_files, info.path)
      end
    end
  else
    -- Forward remaining arguments as flags to cc.
    table.insert(otherflags, name)
  end
end

if #lua_source_files == 0 then
  local version = "0.0.6"
  print("luastatic " .. version)
  print([[
usage: luastatic main.lua[1] require.lua[2] liblua.a[3] library.a[4] -I/include/lua[5] [6]
  [1]: The entry point to the Lua program
  [2]: One or more required Lua source files
  [3]: The path to the Lua interpreter static library
  [4]: One or more static libraries for a required Lua binary module
  [5]: The path to the directory containing lua.h
  [6]: Additional arguments are passed to the C compiler]])
  os.exit()
end

-- The entry point to the Lua program.
local mainlua = lua_source_files[1]
--[[
Generate a C program containing the Lua source files that uses the Lua C API to 
initialize any Lua libraries and run the program.
--]]
local outfile = io.open(mainlua.path .. ".c", "w+")
local function out(...)
  outfile:write(...)
end

out([[
#include <assert.h>
#ifdef __cplusplus
extern "C" {
#endif
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#ifdef __cplusplus
}
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if LUA_VERSION_NUM == 501
  #define LUA_OK 0
#endif

#define arraylen(array) (sizeof(array) / sizeof(array[0]))

struct module
{
  const char *name;
  const unsigned char *buf;
  const unsigned int len;
};
]])

out("extern const struct module lua_bundle[", #lua_source_files, "];", "\n\n");

out([[
/* Try to load the module from lua_bundle when require() is called. */
static int lua_loader(lua_State *l)
{
  size_t namelen;
  const char *modname = lua_tolstring(l, -1, &namelen);
  const struct module *mod = NULL;
  int i = 0;
  for (; i < arraylen(lua_bundle); ++i)
  {
    if
    (
      namelen == strlen(lua_bundle[i].name) && 
      memcmp(modname, lua_bundle[i].name, namelen) == 0
    )
    {
      mod = &lua_bundle[i];
      break;
    }
  }
  if (!mod)
  {
    /* Module not found. */
    lua_pushnil(l);
    return 1;
  }
  if (luaL_loadbuffer(l, (const char*)mod->buf, mod->len, mod->name) != LUA_OK)
  {
    printf("luaL_loadstring: %s %s\n", lua_tostring(l, 1), lua_tostring(l, 2));
    lua_close(l);
    exit(1);
  }
  return 1;
}

/* Copied from lua.c */
static void createargtable (lua_State *L, char **argv, int argc, int script) {
  int i, narg;
  if (script == argc) script = 0;  /* no script name? */
  narg = argc - (script + 1);  /* number of positive indices */
  lua_createtable(L, narg, script + 1);
  for (i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i - script);
  }
  lua_setglobal(L, "arg");
}

#if LUA_VERSION_NUM == 501
/* Copied from https://github.com/keplerproject/lua-compat-5.2 */
static void luaL_requiref (lua_State *L, char const* modname,
                    lua_CFunction openf, int glb) {
  luaL_checkstack(L, 3, "not enough stack slots");
  lua_pushcfunction(L, openf);
  lua_pushstring(L, modname);
  lua_call(L, 1, 1);
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "loaded");
  lua_replace(L, -2);
  lua_pushvalue(L, -2);
  lua_setfield(L, -2, modname);
  lua_pop(L, 1);
  if (glb) {
    lua_pushvalue(L, -1);
    lua_setglobal(L, modname);
  }
}
#endif

int main(int argc, char *argv[])
{
  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  
  /* Add the loader to package.searchers after the package.preload loader. */
  lua_getglobal(L, "table");
  lua_getfield(L, -1, "insert");
  /* remove "table" */
  lua_remove(L, -2);
  assert(lua_isfunction(L, -1));
  lua_getglobal(L, "package");
#if LUA_VERSION_NUM == 501
  lua_getfield(L, -1, "loaders");
#else
  lua_getfield(L, -1, "searchers");
#endif
  /* Remove the package table from the stack. */
  lua_remove(L, -2);
  lua_pushnumber(L, 2);
  lua_pushcfunction(L, lua_loader);
  /* table.insert(package.searchers, 2, lua_loader); */
  lua_call(L, 3, 0);
  assert(lua_gettop(L) == 0);
]]);

for _, library in ipairs(module_library_files) do
  out(('  int luaopen_%s(lua_State *L);\n'):format(library.dotpath_underscore))
  out(('  luaL_requiref(L, "%s", luaopen_%s, 0);\n'):format(
    library.dotpath_noextension, library.dotpath_underscore
  ))
  out('  lua_pop(L, 1);\n\n')
end

out(([[
  /* Run the main Lua program. */
  if (luaL_loadbuffer(L, (const char*)lua_bundle[0].buf, lua_bundle[0].len, "%s"))
  {
    /* Print the error message. */
    puts(lua_tostring(L, 1));
    lua_close(L);
    return 1;
  }
  createargtable(L, argv, argc, 0);
  int err = lua_pcall(L, 0, LUA_MULTRET, 0);
  if (err != LUA_OK)
  {
    puts(lua_tostring(L, 1));
    lua_close(L);
    return 1;
  }
  lua_close(L);
  return 0;
}

]]):format(mainlua.basename))

--[[
Embed Lua source code in the C program.
--]]
for i, file in ipairs(lua_source_files) do
  out("static const unsigned char lua_require_", i, "[] = {\n  ")
  local f = io.open(file.path, "r")
  local prefix = f:read(4)
  if prefix then
    if prefix:match("\xef\xbb\xbf") then
      -- Strip the UTF-8 byte order mark.
      prefix = prefix:sub(4)
    end
    if prefix:match("#") then
      -- Strip the shebang.
      f:read("*line")
      prefix = nil
    end
    if prefix then
      out(string_to_hex(prefix), ", ")
    end
  end
  while true do
    local strdata = f:read(4096)
    if strdata then
      out(string_to_hex(strdata), ", ")
    else
      break
    end
  end
  out("\n};\n")
  f:close()
end

out([[
const struct module lua_bundle[] = 
{
]]);
for i, file in ipairs(lua_source_files) do
  out(('  {"%s", lua_require_%s, sizeof(lua_require_%s)},\n'):format(
    file.dotpath_noextension, i, i
  ))
end
out("};")

out("\n")
outfile:close()

if os.getenv("CC") == "" then
  -- Disable compiling and exit with a success code.
  os.exit(0)
end

if not execute(CC .. " --version 1>/dev/null 2>/dev/null") then
  io.stderr:write("C compiler not found.\n")
  os.exit(1)
end

-- http://lua-users.org/lists/lua-l/2009-05/msg00147.html
local rdynamic = "-rdynamic"
local binary_extension = ""
if shellout(CC .. " -dumpmachine"):match("mingw") then
  rdynamic = ""
  binary_extension = ".exe"
end

local compile_command = table.concat({
  CC,
  "-Os",
  mainlua.path .. ".c",
  -- Link with Lua modules first to avoid linking errors.
  table.concat(module_link_libraries, " "),
  table.concat(dep_library_files, " "),
  rdynamic,
 "-lm",
  link_with_libdl,
  table.concat(otherflags, " "),
  "-o " .. mainlua.basename_noextension .. binary_extension,
}, " ")
print(compile_command)
local ok = execute(compile_command)
if ok then
  os.exit(0)
else
  os.exit(1)
end

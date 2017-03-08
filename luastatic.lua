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
Create a C hex string from the characters of a Lua string.
--]]
local function string_to_hex_literal(characters)
  local hex = {}
  for character in characters:gmatch(".") do
    table.insert(hex, ("0x%02x"):format(string.byte(character)))
  end
  return table.concat(hex, ", ")
end

--[[
Create a Lua decimal string from the characters of a Lua string.
--]]
local function string_to_decimal_literal(characters)
  local hex = {}
  for character in characters:gmatch(".") do
    table.insert(hex, ("\\%i"):format(string.byte(character)))
  end
  return table.concat(hex, "")
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
  local version = "0.0.7"
  print("luastatic " .. version)
  print([[
usage: luastatic main.lua[1] require.lua[2] liblua.a[3] library.a[4] -I/include/lua[5] [6]
  [1]: The entry point to the Lua program
  [2]: One or more required Lua source files
  [3]: The path to the Lua interpreter static library
  [4]: One or more static libraries for a required Lua binary module
  [5]: The path to the directory containing lua.h
  [6]: Additional arguments are passed to the C compiler]])
  os.exit(1)
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
local function outhex(str)
  outfile:write(string_to_hex_literal(str), ", ")
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
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if LUA_VERSION_NUM == 501
  #define LUA_OK 0
#endif

static const char lua_loader_program[] = {
]])

--[[
Embed Lua program source code.
--]]
local function outhex_lua_source(file)
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
      prefix = "\n"
    end
    outhex(string_to_decimal_literal(prefix))
  end
  while true do
    local strdata = f:read(4096)
    if strdata then
      outhex(string_to_decimal_literal(strdata))
    else
      break
    end
  end
  f:close()
end

outhex([[
local lua_bundle = {
]])
for i, file in ipairs(lua_source_files) do
  outhex('["')
  outhex(file.dotpath_noextension)
  outhex('"] = "')
  outhex_lua_source(file)
  outhex('",\n')
end
outhex([[
}
]])

outhex([[
local function load_string(str, name)
  if _VERSION == "Lua 5.1" then
    return loadstring(str, name)
  else
    return load(str, name)
  end
end

local function lua_loader(name)
  local source = lua_bundle[name] or lua_bundle[name .. ".init"]
  if source then
    local chunk, errstr = load_string(source, name)
    if chunk then
      return chunk
    else
      error(
        ("error loading module '%s' from luastatic bundle:\n\t%s"):format(name, errstr),
        0
      )
    end
  else
    return ("\n\tno module '%s' in luastatic bundle"):format(name)
  end
end
table.insert(package.loaders or package.searchers, 2, lua_loader)
]])

outhex(([[
-- Run the main Lua program.
local chunk, errstr = load_string(lua_bundle["%s"], "%s")
if chunk then
  chunk()
else
  error(errstr, 0)
end
]]):format(mainlua.dotpath_noextension, mainlua.basename_noextension))

out([[

};

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

/* Copied from lua.c */

static lua_State *globalL = NULL;

static void lstop (lua_State *L, lua_Debug *ar) {
  (void)ar;  /* unused arg. */
  lua_sethook(L, NULL, 0, 0);  /* reset hook */
  luaL_error(L, "interrupted!");
}

static void laction (int i) {
  signal(i, SIG_DFL); /* if another SIGINT happens, terminate process */
  lua_sethook(globalL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

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

static int msghandler (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {  /* is error object not a string? */
    if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
        lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
      return 1;  /* that is the message */
    else
      msg = lua_pushfstring(L, "(error object is a %s value)",
                               luaL_typename(L, 1));
  }
  /* Call debug.traceback() instead of luaL_traceback() for Lua 5.1 compatibility. */
  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  /* debug */
  lua_remove(L, -2);
  lua_pushstring(L, msg);
  /* original msg */
  lua_remove(L, -3);
  lua_pushinteger(L, 2);  /* skip this function and traceback */
  lua_call(L, 2, 1); /* call debug.traceback */
  return 1;  /* return the traceback */
}

static int docall (lua_State *L, int narg, int nres) {
  int status;
  int base = lua_gettop(L) - narg;  /* function index */
  lua_pushcfunction(L, msghandler);  /* push message handler */
  lua_insert(L, base);  /* put it under function and args */
  globalL = L;  /* to be available to 'laction' */
  signal(SIGINT, laction);  /* set C-signal handler */
  status = lua_pcall(L, narg, nres, base);
  signal(SIGINT, SIG_DFL); /* reset C-signal handler */
  lua_remove(L, base);  /* remove message handler from the stack */
  return status;
}

int main(int argc, char *argv[])
{
  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  createargtable(L, argv, argc, 0);

]])

for _, library in ipairs(module_library_files) do
  out(('  int luaopen_%s(lua_State *L);\n'):format(library.dotpath_underscore))
  out(('  luaL_requiref(L, "%s", luaopen_%s, 0);\n'):format(
    library.dotpath_noextension, library.dotpath_underscore
  ))
  out('  lua_pop(L, 1);\n')
end

out(([[  
  /*printf("%%.*s", (int)sizeof(lua_loader_program), lua_loader_program);*/
  if (luaL_loadbuffer(L, lua_loader_program, sizeof(lua_loader_program), "%s") != LUA_OK)
  {
    fprintf(stderr, "luaL_loadstring: %%s %%s\n", lua_tostring(L, 1), lua_tostring(L, 2));
    lua_close(L);
    return 1;
  }
  if (docall(L, 0, LUA_MULTRET))
  {
    const char *errmsg = lua_tostring(L, 1);
    if (errmsg)
    {
      fprintf(stderr, "%%s\n", errmsg);
    }
    lua_close(L);
    return 1;
  }
  lua_close(L);
  return 0;
}
]]):format(mainlua.basename_noextension));

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
  "-o " .. mainlua.basename_noextension .. binary_extension,
  table.concat(otherflags, " "),
}, " ")
print(compile_command)
local ok = execute(compile_command)
if ok then
  os.exit(0)
else
  os.exit(1)
end

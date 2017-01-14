#!/usr/bin/env lua

-- The author disclaims copyright to this source code.

local mainlua
local lua_source_files = {}
local module_library_files = {}
local module_link_libs = {}
local dep_library_files = {}
local otherflags = {}

local CC = os.getenv("CC") or "cc"
local NM = os.getenv("NM") or "nm"

local function file_exists(name)
  local f = io.open(name, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function shellout(cmd)
  local f = io.popen(cmd)
  local str = f:read("*all")
  local ok, errstr, errnum = f:close()
  if ok then
    return str, errnum
  end
  return nil
end

local function shared_library_exists(lib)
  local cmd = ([[
echo "int main(int argc, char *argv[]) { return 0; }" |\
%s -l%s -o /dev/null -xc - 1>/dev/null 2>/dev/null
]]):format(CC, lib)
  local str, errnum = shellout(cmd)
  return errnum == 0
end

-- parse arguments
for i, name in ipairs(arg) do
  local extension = name:match("%.(%a+)$")
  if 
    extension == "lua" or 
    extension == "a" or 
    extension == "so" or 
    extension == "dylib" 
  then
    if not file_exists(name) then
      print("file does not exist: ", name)
      os.exit(1)
    end

    local info = {}
    info.path = name
    info.basename = io.popen("basename " .. info.path):read("*line")
    info.basename_noextension = info.basename:match("(.+)%.")
    info.basename_underscore = info.basename_noextension:gsub("%.", "_")
    info.basename_underscore = info.basename_underscore:gsub("%-", "_")
    info.dotpath = info.path:gsub("/", ".")
    info.dotpath_noextension = info.dotpath:match("(.+)%.")
    info.dotpath_underscore = info.dotpath_noextension:gsub("%.", "_")
    info.dotpath_underscore = info.dotpath_underscore:gsub("%-", "_")

    if extension == "lua" then
      table.insert(lua_source_files, info)
    elseif 
      extension == "a" or 
      extension == "so" or 
      extension == "dylib" 
    then
      -- the library is either a Lua module or a library dependency
      local nmout = shellout(NM .. " " .. info.path)
      if not nmout then
        print("nm not found")
        os.exit(1)
      end
      local is_module = false
      if not nmout:find("T _?luaL_newstate") then
        for luaopen in nmout:gmatch("[^dD] _?luaopen_([%a%p%d]+)") do
          local modinfo = {}
          modinfo.path = info.path
          modinfo.dotpath_underscore = luaopen
          modinfo.dotpath = modinfo.dotpath_underscore:gsub("_", ".")
          modinfo.dotpath_noextension = modinfo.dotpath
          -- print(modinfo.path, modinfo.dotpath, modinfo.dotpath_underscore, modinfo.dotpath_noextension)
          is_module = true
          table.insert(module_library_files, modinfo)
        end
      end
      if is_module then
        table.insert(module_link_libs, info)
      else
        table.insert(dep_library_files, info)
      end
    end
  else
    -- forward remaining arguments as flags to cc
    table.insert(otherflags, name)
  end
end
local otherflags_str = table.concat(otherflags, " ")

if #lua_source_files == 0 then
  local version = "0.0.5"
  print("luastatic " .. version)
  print([[
usage: luastatic main.lua[1] require.lua[2] liblua.a[3] module.a[4] -I/include/lua[5] [6]
  [1]: The entry point to the Lua program
  [2]: One or more required Lua source files
  [3]: The path to the Lua interpreter static library
  [4]: One or more static libraries for a required Lua binary module
  [5]: The path to the directory containing lua.h
  [6]: Additional arguments are passed to the C compiler]])
  os.exit()
end
mainlua = lua_source_files[1]

local function binToHexString(bindata)
  local hex = {}
  for b in bindata:gmatch"." do
    table.insert(hex, ("0x%02x"):format(string.byte(b)))
  end
  local hexstr = table.concat(hex, ", ")
  return hexstr
end

local luaprogramcdata = {}
local lua_module_require = {}
local lua_module_require_template = [[struct module
{
  char *name;
  unsigned char *buf;
  unsigned int len;
} const static lua_bundle[] = 
{
%s
};
]]
for i, v in ipairs(lua_source_files) do
  local f = io.open(v.path, "r")
  local strdata = f:read("*all")
  f:close()
  if strdata:sub(1, 3) == "\xef\xbb\xbf" then
    -- strip the byte order mark
    strdata = strdata:sub(4)
  end
  if strdata:sub(1, 1) == '#' then
    local newline = strdata:find("\n")
    if newline then
      -- strip the shebang on the first line
      strdata = strdata:sub(newline + 1)
    else
      -- EOF before newline
      strdata = ""
    end
  end
  local hexstr = binToHexString(strdata)
  local fmt = [[static unsigned char lua_require_%s[] = {%s};]]
  table.insert(luaprogramcdata, fmt:format(i, hexstr))
  table.insert(lua_module_require, 
    ("\t{\"%s\", lua_require_%s, %s},"):format(v.dotpath_noextension, i, #strdata)
  )
end
local lua_module_requirestr = lua_module_require_template:format(
  table.concat(lua_module_require, "\n")
)
local luaprogramcdatastr = table.concat(luaprogramcdata, "\n")

local bin_module_require = {}
local bin_module_require_template = [[  int luaopen_%s(lua_State *L);
  luaL_requiref(L, "%s", luaopen_%s, 0);
  lua_pop(L, 1);
]]
for i, v in ipairs(module_library_files) do
  table.insert(bin_module_require, bin_module_require_template:format(
    v.dotpath_underscore, v.dotpath_noextension, v.dotpath_underscore)
  )
end
local bin_module_requirestr = table.concat(bin_module_require, "\n")

local cprog = ([[
#include <assert.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if LUA_VERSION_NUM == 501
  #define LUA_OK 0
#endif

#define arraylen(array) (sizeof(array) / sizeof(array[0]))

%s

%s

// try to load the module from lua_bundle when require() is called
static int lua_loader(lua_State *l)
{
  size_t namelen;
  const char *modname = lua_tolstring(l, -1, &namelen);
  //printf("lua_loader: %%i %%.*s\n", (unsigned)namelen, (int)namelen, modname);
  const struct module *mod = NULL;
  for (int i = 0; i < arraylen(lua_bundle); ++i)
  {
    if (namelen == strlen(lua_bundle[i].name) && memcmp(modname, lua_bundle[i].name, namelen) == 0)
    {
      mod = &lua_bundle[i];
      break;
    }
  }
  if (!mod)
  {
    //printf("module not found: %%s\n", modname);
    lua_pushnil(l);
    return 1;
  }
  if (luaL_loadbuffer(l, (const char*)mod->buf, mod->len, mod->name) != LUA_OK)
  {
    printf("luaL_loadstring: %%s %%s\n", lua_tostring(l, 1), lua_tostring(l, 2));
    lua_close(l);
    exit(1);
  }
  return 1;
}

// copied from lua.c
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
// copied from https://github.com/keplerproject/lua-compat-5.2
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
  
  // add loader to package.searchers after the package.preload loader
  lua_getglobal(L, "table");
  lua_getfield(L, -1, "insert");
  // remove "table"
  lua_remove(L, -2);
  assert(lua_isfunction(L, -1));
  lua_getglobal(L, "package");
#if LUA_VERSION_NUM == 501
  lua_getfield(L, -1, "loaders");
#else
  lua_getfield(L, -1, "searchers");
#endif
  // remove package table from the stack
  lua_remove(L, -2);
  lua_pushnumber(L, 2);
  lua_pushcfunction(L, lua_loader);
  // table.insert(package.searchers, 2, lua_loader);
  lua_call(L, 3, 0);
  assert(lua_gettop(L) == 0);
  
%s
  
  if (luaL_loadbuffer(L, (const char*)lua_bundle[0].buf, lua_bundle[0].len, "%s"))
  {
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
]]):format(
  luaprogramcdatastr, lua_module_requirestr, bin_module_requirestr, 
  mainlua.basename_underscore
)
local infilename = lua_source_files[1].path
local outfile = io.open(infilename .. ".c", "w+")
outfile:write(cprog)
outfile:close()

if not shellout(CC .. " --version") then
  print("C compiler not found.")
  os.exit(1)
end

local linklibs = {}
for i, v in ipairs(module_link_libs) do
  table.insert(linklibs, v.path)
end
for i, v in ipairs(dep_library_files) do
  table.insert(linklibs, v.path)
end
local linklibstr = table.concat(linklibs, " ")
local ccformat = "%s -Os -std=c99 %s.c %s %s -lm %s %s -o %s%s"
-- http://lua-users.org/lists/lua-l/2009-05/msg00147.html
local rdynamic = "-rdynamic"
local ldl = ""
if shared_library_exists("dl") then
  ldl = "-ldl"
end
local binary_extension = ""
if shellout(CC .. " -dumpmachine"):match("mingw") then
  rdynamic = ""
  binary_extension = ".exe"
end
local ccstr = ccformat:format(
  CC, infilename, linklibstr, rdynamic, ldl, otherflags_str, 
  mainlua.basename_noextension, binary_extension
)
print(ccstr)
shellout(ccstr)

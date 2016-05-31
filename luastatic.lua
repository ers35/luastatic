#!/usr/bin/env lua

-- The author disclaims copyright to this source code.

local mainlua
local lua_source_files = {}
local module_library_files = {}
local dep_library_files = {}
local otherflags = {}

local function fileExists(name)
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
  if f:close() then
    return str
  end
  return nil
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
    if not fileExists(name) then
      print("file does not exist: ", name)
      os.exit(1)
    end

    local info = {}
    info.name = name
    info.basename = io.popen("basename " .. name):read("*line")
    info.basename_noextension = info.basename:match("(.+)%.")
    info.basename_underscore = info.basename_noextension:gsub("%.", "_")
    info.basename_underscore = info.basename_underscore:gsub("%-", "_")

    if extension == "lua" then
      table.insert(lua_source_files, info)
    elseif 
      extension == "a" or 
      extension == "so" or 
      extension == "dylib" 
    then
      -- the library either a Lua module or a library dependency
      local nmout = shellout("nm " .. name)
      if not nmout then
        print("nm not found")
        os.exit(1)
      end
      if nmout:find("luaopen_" .. info.basename_noextension) then
        table.insert(module_library_files, info)
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
  print("usage: luastatic main.lua /path/to/liblua.a -I/directory/containing/lua.h/")
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
  local f = io.open(v.name, "r")
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
    ("\t{\"%s\", lua_require_%s, %s},"):format(
      v.name:gsub("/", "."):gsub("%.lua$", ""), i, #strdata
    )
  )
end
local lua_module_requirestr = lua_module_require_template:format(
  table.concat(lua_module_require, "\n")
)
local luaprogramcdatastr = table.concat(luaprogramcdata, "\n")

local bin_module_require = {}
local bin_module_require_template = [[int luaopen_%s(lua_State *L);
  luaL_requiref(L, "%s", luaopen_%s, 0);
  lua_pop(L, 1);
]]
for i, v in ipairs(module_library_files) do
  table.insert(bin_module_require, bin_module_require_template:format(
    v.basename_underscore, v.basename_noextension, v.basename_underscore)
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
    printf("luaL_loadstring: %%s\n", lua_tostring(l, 1));
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

int main(int argc, char *argv[])
{
  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  
  // add loader to package.searchers
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
  lua_pushcfunction(L, lua_loader);
  // table.insert(package.searchers, lua_loader);
  lua_call(L, 2, 0);
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
local infilename = lua_source_files[1].name
local outfile = io.open(infilename .. ".c", "w+")
outfile:write(cprog)
outfile:close()

local CC = os.getenv("CC") or "cc"
if not shellout(CC .. " --version") then
  print("C compiler not found.")
  os.exit(1)
end

local linklibs = {}
for i, v in ipairs(module_library_files) do
  table.insert(linklibs, v.name)
end
for i, v in ipairs(dep_library_files) do
  table.insert(linklibs, v.name)
end
local linklibstr = table.concat(linklibs, " ")
local ccformat = "%s -Os -std=c99 %s.c %s %s -lm %s %s -o %s%s"
-- http://lua-users.org/lists/lua-l/2009-05/msg00147.html
local rdynamic = "-rdynamic"
local ldl = "-ldl"
local binary_extension = ""
if shellout(CC .. " -dumpmachine"):match("mingw") then
  rdynamic = ""
  ldl = ""
  binary_extension = ".exe"
end
local ccstr = ccformat:format(
  CC, infilename, linklibstr, rdynamic, ldl, otherflags_str, 
  mainlua.basename_noextension, binary_extension
)
print(ccstr)
shellout(ccstr)

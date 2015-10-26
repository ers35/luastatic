-- The author disclaims copyright to this source code.

--~ local inspect = require"inspect"

local lua_source_files = {}
local liblua
local module_library_files = {}
local dep_library_files = {}
local otherflags = {}

function fileExists(name)
  local f = io.open(name, "r")
  if f then
    f:close()
    return f ~= nil
  end
  return false
end

-- parse arguments
for i, name in ipairs(arg) do
  local extension = name:match("%.(.+)$")
  if extension == "lua" or extension == "a" then
    if not fileExists(name) then
      print("file does not exist: ", name)
      os.exit(1)
    end
    local info = {}
    info.name = name
    info.basename = io.popen(("basename %s"):format(name)):read("*line")
    info.basename_noextension = info.basename:match("(.+)%.")
    if extension == "lua" then
      table.insert(lua_source_files, info)
    elseif extension == "a" then
      -- the library is one of three types: liblua.a, a Lua module, or a library dependency
      local nm = io.popen("nm " .. name)
      local nmout = nm:read("*all")
      if not nm:close() then
        print("nm not found")
        os.exit(1)
      end
      if nmout:find("luaL_newstate") then
        liblua = info
      elseif nmout:find(("luaopen_%s"):format(info.basename_noextension)) then
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

--~ print(inspect(lua_source_files))
--~ print(inspect(module_library_files))
--~ print(otherflags_str)

if #lua_source_files == 0 or liblua == nil then
  print("usage: luastatic main.lua /path/to/liblua.a")
  os.exit()
end

local CC = "cc"
do
  local f = io.popen(CC .. " --version")
  f:read("*all")
  if not f:close() then
    print("C compiler not found.")
    os.exit(1)
  end
end

local infile = lua_source_files[1].name
local infd = io.open(infile, "r")
if not infd then
  print(("Lua file not found: %s"):format(infile))
  os.exit(1)
end

function binToCData(bindata, name)
  local fmt = [[
unsigned char %s_lua[] = {
%s
};
unsigned int %s_lua_len = %u;
]]
  local hex = {}
  for b in bindata:gmatch"." do
    table.insert(hex, ("0x%02x"):format(string.byte(b)))
  end
  local hexstr = table.concat(hex, ", ")
  return fmt:format(name, hexstr, name, #bindata)
end

local basename = io.popen(("basename %s"):format(infile)):read("*all")
local basename_noextension = basename:match("(.+)%.")
local basename_underscore = basename_noextension:gsub("%.", "_")

function luaProgramToCData(filename)
  local f = io.open(filename, "r")
  local strdata = f:read("*all")
  -- load the chunk to check for syntax errors
  local chunk, err = load(strdata)
  if not chunk then
    print(("load: %s"):format(err))
    os.exit(1)
  end
  local bindata = string.dump(chunk)
  f:close()
  return binToCData(bindata, basename_underscore)
end

local luaprogramcdata = luaProgramToCData(infile)

local module_require = {}
local module_require_template = [[int luaopen_%s(lua_State *L);
  luaL_requiref(L, "%s", luaopen_%s, 0);
  lua_pop(L, 1);
]]
for i, v in ipairs(module_library_files) do
  local noext = v.basename_noextension
  table.insert(module_require, module_require_template:format(noext, noext, noext))
end
local module_requirestr = table.concat(module_require, "\n")

local cprog = ([[
//#include <lauxlib.h>
//#include <lua.h>
//#include <lualib.h>
#include <stdio.h>

%s

// try to avoid having to resolve the Lua include path
typedef struct lua_State lua_State;
typedef int (*lua_CFunction) (lua_State *L);
lua_State *(luaL_newstate) (void);
void (luaL_openlibs) (lua_State *L);
const char     *(lua_tolstring) (lua_State *L, int idx, size_t *len);
#define lua_tostring(L,i)	lua_tolstring(L, (i), NULL)
const char *(lua_pushstring) (lua_State *L, const char *s);
void  (lua_setglobal) (lua_State *L, const char *var);
void  (lua_rawseti) (lua_State *L, int idx, int n);
#define LUA_MULTRET	(-1)
#define LUA_OK		0
int (luaL_loadbufferx) (lua_State *L, const char *buff, size_t sz,
                                   const char *name, const char *mode);
#define luaL_loadbuffer(L,s,sz,n)	luaL_loadbufferx(L,s,sz,n,NULL)
int   (lua_pcallk) (lua_State *L, int nargs, int nresults, int errfunc,
                            int ctx, lua_CFunction k);
#define lua_pcall(L,n,r,f)	lua_pcallk(L, (n), (r), (f), 0, NULL)
void  (lua_createtable) (lua_State *L, int narr, int nrec);
void  (lua_settop) (lua_State *L, int idx);
#define lua_pop(L,n)		lua_settop(L, -(n)-1)
void (luaL_requiref) (lua_State *L, const char *modname,
                                 lua_CFunction openf, int glb);

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

int
main(int argc, char *argv[])
{
  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  
  %s
  
  if (luaL_loadbuffer(L, (const char*)%s_lua, %s_lua_len, "%s"))
  {
    puts(lua_tostring(L, 1));
    return 1;
  }
  createargtable(L, argv, argc, 0);
  int err = lua_pcall(L, 0, LUA_MULTRET, 0);
  if (err != LUA_OK)
  {
    puts(lua_tostring(L, 1));
    return 1;
  }
  return 0;
}
]]):format(
  luaprogramcdata, module_requirestr, basename_underscore, basename_underscore, 
  basename_underscore
)
local outfile = io.open(("%s.c"):format(infile), "w+")
outfile:write(cprog)
outfile:close()

do
  -- statically link Lua, but dynamically link everything else
  -- http://lua-users.org/lists/lua-l/2009-05/msg00147.html
  local linklibs = {}
  for i, v in ipairs(module_library_files) do
    table.insert(linklibs, v.name)
  end
  for i, v in ipairs(dep_library_files) do
    table.insert(linklibs, v.name)
  end
  local linklibstr = table.concat(linklibs, " ")
  local ccformat 
    = "%s -Os %s.c -rdynamic %s %s -lm -ldl %s -o %s"
  local ccformat = ccformat:format(
    CC, infile, liblua.name, linklibstr, otherflags_str, basename_noextension
  )
  print(ccformat)
  io.popen(ccformat):read("*all")
end

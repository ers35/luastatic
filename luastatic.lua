-- The author disclaims copyright to this source code.

local infile = arg[1]
local libluapath = arg[2]
if not infile or not libluapath then
  print("usage: luastatic infile.lua /path/to/liblua.a")
  os.exit()
end

if libluapath then
  local f = io.open(libluapath, "r")
  if not f then
    print(("liblua.a not found: %s"):format(libluapath))
    os.exit(1)
  end
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
basename = basename:match("(.+)%.")

function luaProgramToCData(filename)
  --~ local basename = filename:match("(.+)%.")
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
  return binToCData(bindata, basename)
end

local luaprogramcdata = luaProgramToCData(infile)

--~ local basename = infile:match("(.+)%.")
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
const char     *(lua_tolstring) (lua_State *L, int idx, size_t *len);
#define lua_tostring(L,i)	lua_tolstring(L, (i), NULL)
#define LUA_MULTRET	(-1)
#define LUA_OK		0
int (luaL_loadbufferx) (lua_State *L, const char *buff, size_t sz,
                                   const char *name, const char *mode);
#define luaL_loadbuffer(L,s,sz,n)	luaL_loadbufferx(L,s,sz,n,NULL)
int   (lua_pcallk) (lua_State *L, int nargs, int nresults, int errfunc,
                            int ctx, lua_CFunction k);
#define lua_pcall(L,n,r,f)	lua_pcallk(L, (n), (r), (f), 0, NULL)

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
]]):format(luaprogramcdata, basename, basename, basename)
local outfile = io.open(("%s.c"):format(infile), "w+")
outfile:write(cprog)
outfile:close()

do
  -- statically link Lua, but dynamically link everything else
  -- http://lua-users.org/lists/lua-l/2009-05/msg00147.html
  local ccformat 
    = "%s -Os %s.c -rdynamic %s -lm -ldl -o %s"
  local ccformat = ccformat:format(CC, infile, libluapath, basename)
  print(ccformat)
  io.popen(ccformat):read("*all")
end

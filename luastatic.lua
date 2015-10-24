-- The author disclaims copyright to this source code.

local infile = arg[1]
if not infile then
  print("usage: luastatic infile.lua")
  os.exit()
end

local CC = os.getenv("CC") or "gcc"
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

function fileToBlob(filename)
  local basename = filename:match("(.+)%.")
  local fmt = [[
unsigned char %s_lua[] = {
%s
};
unsigned int %s_lua_len = %u;
]]
  local f = io.open(filename, "r")
  local strdata = f:read("*all")
  -- load the chunk to check for syntax errors
  local chunk, err = load(strdata)
  if not chunk then
    print(("load: %s"):format(err))
    os.exit(1)
  end
  local bindata = string.dump(chunk)
  local hex = {}
  for b in bindata:gmatch"." do
    table.insert(hex, ("0x%02x"):format(string.byte(b)))
  end
  local hexstr = table.concat(hex, ", ")
  f:close()
  return fmt:format(basename, hexstr, basename, #bindata)
end

--~ local cdata = io.popen(("xxd -i %s"):format(infile)):read("*all")
local cdata = fileToBlob(infile)

local basename = infile:match("(.+)%.")
local cprog = ([[
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stdio.h>

%s

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
]]):format(cdata, basename, basename, basename)
local outfile = io.open(("%s.c"):format(infile), "w+")
outfile:write(cprog)
outfile:close()

do
  -- statically link Lua, but dynamically link everything else
  -- http://lua-users.org/lists/lua-l/2009-05/msg00147.html
  local gccformat 
    = "%s -Os %s.c -Wl,--export-dynamic -Wl,-Bstatic `pkg-config --cflags --libs lua5.2` -Wl,-Bdynamic -lm -ldl -o %s"
  local gccstr = gccformat:format(CC, infile, basename)
  --~ print(gccstr)
  io.popen(gccstr):read("*all")
end

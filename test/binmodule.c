#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

static const luaL_Reg binmodulelib[] = {
  {NULL, NULL},
};

LUALIB_API int luaopen_binmodule(lua_State *L)
{
  luaL_newlib(L, binmodulelib);
  return 1;
}

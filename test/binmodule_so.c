// Fails without -rdynamic flag to cc

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

static const luaL_Reg binmodulelib[] = {
  {NULL, NULL},
};

LUALIB_API int luaopen_binmodule_so(lua_State *L)
{
#if LUA_VERSION_NUM == 501
  luaL_register(L, "binmodulelib", binmodulelib);
#else
  luaL_newlib(L, binmodulelib);
#endif
  return 1;
}

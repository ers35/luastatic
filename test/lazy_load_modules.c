#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stdio.h>

static const luaL_Reg lazymodulelib[] = {
  {NULL, NULL},
};

LUALIB_API int luaopen_lazymodule_1(lua_State *L)
{
#if LUA_VERSION_NUM == 501
  luaL_register(L, "lazymodulelib", lazymodulelib);
#else
  luaL_newlib(L, lazymodulelib);
#endif
  return 1;
}

LUALIB_API int luaopen_lazymodule_2(lua_State *L)
{
  _Exit(1);
}

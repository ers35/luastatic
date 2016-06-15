#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

static const luaL_Reg binmodule_dotslib[] = {
  {NULL, NULL},
};

LUALIB_API int luaopen_binmodule_dots(lua_State *L)
{
#if LUA_VERSION_NUM == 501
  luaL_register(L, "binmodule_dotslib", binmodule_dotslib);
#else
  luaL_newlib(L, binmodule_dotslib);
#endif
  return 1;
}

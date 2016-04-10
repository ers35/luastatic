#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

static const luaL_Reg binmodule_dotslib[] = {
  {NULL, NULL},
};

LUALIB_API int luaopen_binmodule_dots(lua_State *L)
{
  luaL_newlib(L, binmodule_dotslib);
  return 1;
}

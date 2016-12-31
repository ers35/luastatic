#include <lua.hpp>

// Test to make sure luastatic does not find a mangled symbol.
// LUALIB_API is purposely not used here.
int luaopen_mangled(lua_State *L)
{
  
}

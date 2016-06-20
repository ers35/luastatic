package = "luastatic"
version = "0.0.3-1"
source =
{
  url = "git://github.com/ers35/luastatic.git",
  tag = "0.0.3",
}
description =
{
  summary = "Build a standalone executable from a Lua program.",
  detailed = [[
    See http://lua.space/tools/build-a-standalone-executable for more information.
  ]],
  homepage = "https://www.github.com/ers35/luastatic",
  license = "CC0",
  maintainer = "Eric R. Schulz <eric@ers35.com>"
}
dependencies = { "lua >= 5.1" }
build =
{
  type = "builtin",
  modules = {},
  install = {
    bin = {
      ["luastatic"] = "luastatic.lua",
    }
  }
}

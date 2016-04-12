package = "luastatic"
version = "scm-1"
source =
{
  url = "git://github.com/ers35/luastatic.git",
  branch = "master"
}
description =
{
  summary = "Build a standalone executable from a Lua program.",
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

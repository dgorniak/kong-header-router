package = "kong-plugin-header-router"

version = "0.1.0-2"

local pluginName = package:match("^kong%-plugin%-(.+)$")  -- "header-router"

supported_platforms = {"linux", "macosx"}

source = {
  url = "https://github.com/dgorniak/kong-header-router",
  tag = "0.1.0"
}

description = {
  summary = "Kong plugin to override default service upstream based on custom headers.",
  license = "Apache 2.0"
}

dependencies = {
  "lua >= 5.1"
}

build = {
  type = "builtin",
  modules = {
    -- TODO: add any additional files that the plugin consists of
    ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
    ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
  }
}

local kong  = kong

local HeaderRouter = {
  PRIORITY = 600,
  VERSION = "0.1",
}

function HeaderRouter:access(plugin_conf)

  local rules = plugin_conf.rules

  local alternateUpstream = find_corresponding_upstream(rules)

  if alternateUpstream then
    local ok, err = kong.service.set_upstream(alternateUpstream)
    if not ok then
      kong.log.err(err)
      return
    end
  end

end

function find_corresponding_upstream(rules)
  for i,rule in ipairs(rules) do
    local ruleUpstream = rule["upstream_name"]

    for headerName,headerValue in pairs(rule.condition) do
      local requestHeaderValue = kong.request.get_header(headerName)
      if requestHeaderValue ~= headerValue then return end
    end

    return ruleUpstream
  end
end

return HeaderRouter

local kong  = kong


local HeaderRouter = {
  PRIORITY = 600,
  VERSION = "0.1",
}


local function match_rule(rule)
  for header_name,header_value in pairs(rule.condition) do
    local request_header_value = kong.request.get_header(header_name)

    if request_header_value ~= header_value then
      return
    end
  end

  return true
end


local function find_corresponding_upstream(rules)
  for i,rule in ipairs(rules) do
    local rule_upstream = rule["upstream_name"]

    if match_rule(rule) then
      return rule_upstream
    end
  end
end


function HeaderRouter:access(plugin_conf)

  local rules = plugin_conf.rules

  local alternate_upstream = find_corresponding_upstream(rules)

  if alternate_upstream then
    local ok, err = kong.service.set_upstream(alternate_upstream)
    if not ok then
      kong.log.err(err)
      return
    end
  end
end


return HeaderRouter

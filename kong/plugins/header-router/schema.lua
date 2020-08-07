local typedefs = require "kong.db.schema.typedefs"

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local function validate_rules(config)
  for i, rule in ipairs(config.rules) do
    local condition_headers = {}
    for header_name, header_value in pairs(rule.condition) do
      print("Configuration headers " .. header_name .. ":" .. header_value)
      if condition_headers[header_name] == true then
        print("Header already set validation error: " .. header_name)
        return nil, string.format("The header %s is already used in current rule", header_name)
      else
        print("Setting header: " .. header_name)
        condition_headers[header_name] = true
      end
    end
  end
  return true
end

local schema = {
  name = plugin_name,
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { rules = {
              type = "array",
              required = true,
              elements = {
                type = "record",
                fields = {
                  { condition = {
                      type = "map",
                      keys = typedefs.header_name {
                        type = "string"
                      },
                      values = {
                        type = "string"
                      }
                  }},
                  {upstream_name = {
                    type = "string",
                    required = true
                  }}
                }
              }
          }, },
        },
        custom_validator = validate_rules,
      },
    },
  },
}

return schema

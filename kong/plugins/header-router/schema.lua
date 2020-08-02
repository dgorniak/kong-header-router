local typedefs = require "kong.db.schema.typedefs"

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local schema = {
  name = plugin_name,
  fields = {
    -- the 'fields' array is the top-level entry with fields defined by Kong
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer (typical for auth plugins)
    { protocols = typedefs.protocols_http },
    { config = {
        -- The 'config' record is the custom part of the plugin schema
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
        entity_checks = {

        },
      },
    },
  },
}

return schema

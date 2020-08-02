local typedefs = require "kong.db.schema.typedefs"

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local schema = {
  name = plugin_name,
  fields = {
    { consumer = typedefs.no_consumer },  -- this plugin cannot be configured on a consumer
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
        entity_checks = {

        },
      },
    },
  },
}

return schema

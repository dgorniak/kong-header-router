local PLUGIN_NAME = "header-router"


-- helper function to validate data against a schema
local validate do
  local validate_entity = require("spec.helpers").validate_plugin_config_schema
  local plugin_schema = require("kong.plugins."..PLUGIN_NAME..".schema")

  function validate(data)
    return validate_entity(data, plugin_schema)
  end
end


describe(PLUGIN_NAME .. ": (schema)", function()

  it("accepts proper configuration with one rule", function()
    local ok, err = validate(
      { rules = {
        { condition = {["X-Country"] = "Italy", ["X-Regione"] = "Abruzzo"},
          upstream_name = "italy_cluster" },
      }})
    assert.is_nil(err)
    assert.is_truthy(ok)
  end)


  it("does not accept configuration with missing upstream_name", function()
    local ok, err = validate(
      { rules = {
        { condition = {["X-Country"] = "Italy", ["X-Regione"] = "Abruzzo"}, },
      }})

    assert.is_truthy(err)
    assert.is_falsy(ok)
  end)

  it("does not accept empty configuration", function()
    local ok, err = validate(
      { })

    assert.is_truthy(err)
    assert.is_falsy(ok)
  end)

  it("condition can't contain duplicated headers", function()
    local ok, err = validate(
      { rules = {
        { condition = {["X-Country"] = "Italy", ["X-Country"] = "Poland"},
          upstream_name = "italy_cluster" },
      }})
    assert.is_truthy(err)
    assert.is_nil(ok)
    
  end)

end)

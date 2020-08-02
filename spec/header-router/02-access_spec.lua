local helpers = require "spec.helpers"
local bu = require "spec.fixtures.balancer_utils"

local PLUGIN_NAME = "header-router"
local REQUEST_COUNT = 1
local ROUTE_PATH = "/local"

for _, strategy in helpers.each_strategy() do
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()

    local client
    local defaultPort
    local alternatePort
    local defaultServer
    local alternateServer

    lazy_setup(function()

      local bp = helpers.get_db_utils(strategy, nil, { PLUGIN_NAME })

      local defaultUpstream = bp.upstreams:insert({
        name = "europe_cluster"
      })

      defaultPort = bu.add_target(bp, defaultUpstream.id, "127.0.0.1")

      local alternateUpstream = bp.upstreams:insert({
        name = "italy_cluster"
      })

      alternatePort = bu.add_target(bp, alternateUpstream.id, "127.0.0.1")

      local service = bp.services:insert {
        protocol = "http",
        name = "mock_service",
        host = "europe_cluster"
      }

      local route = bp.routes:insert({
        paths = {ROUTE_PATH},
        service = {id = service.id}
      })

      bp.plugins:insert {
        name = PLUGIN_NAME,
        service = { id = service.id },
        config = {
          rules = {
            { condition = {["X-Country"] = "Italy", ["X-Regione"] = "Abruzzo"}, upstream_name = "italy_cluster" },
          }
        },
      }

      -- start kong
      assert(helpers.start_kong({
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
        plugins = "bundled," .. PLUGIN_NAME,
      }))
    end)

    lazy_teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_client()

      -- setup target servers
      defaultServer =  bu.http_server("127.0.0.1", defaultPort, {REQUEST_COUNT}, "false", "http")
      alternateServer = bu.http_server("127.0.0.1", alternatePort, {REQUEST_COUNT}, "false", "http")

    end)

    after_each(function()
      if client then client:close() end
    end)


    describe("header router", function()
      it("routes to default upstream if routing header is not set", function()
        for i=1,REQUEST_COUNT do
          local r = client:get(ROUTE_PATH)

          assert.response(r).has.status(200)
        end

        -- collect server results; hitcount
        local _, defaultRequestCount, defaultErrors = defaultServer:done()
        local _, alternateRequestCount, alternateErrors = alternateServer:done()

        -- verify
        assert.same({REQUEST_COUNT, 0}, {defaultRequestCount, defaultErrors})
        assert.same({0, 0}, {alternateRequestCount, alternateErrors})

      end)
    end)

    it("routes to alternate upstream if all rule headers are set", function()
      for i=1,REQUEST_COUNT do
        local r = client:get(ROUTE_PATH, {
          headers = {
            ["X-Country"] = "Italy", ["X-Regione"] = "Abruzzo"
          }
        })

        assert.response(r).has.status(200)
      end

      local _, defaultRequestCount, defaultErrors = defaultServer:done()
      local _, alternateRequestCount, alternateErrors = alternateServer:done()

      -- verify
      assert.same({0, 0}, {defaultRequestCount, defaultErrors})
      assert.same({REQUEST_COUNT, 0}, {alternateRequestCount, alternateErrors})


    end)

    it("routes to default upstream if not all rule headers are set", function()
      for i=1,REQUEST_COUNT do
        local r = client:get(ROUTE_PATH, {
          headers = {
            ["X-Country"] = "Italy"
          }
        })

        assert.response(r).has.status(200)
      end

      local _, defaultRequestCount, defaultErrors = defaultServer:done()
      local _, alternateRequestCount, alternateErrors = alternateServer:done()

      -- verify
      assert.same({REQUEST_COUNT, 0}, {defaultRequestCount, defaultErrors})
      assert.same({0, 0}, {alternateRequestCount, alternateErrors})


    end)

    it("doesn't change default upstream for request not mapped by associated route", function()
      for i=1,REQUEST_COUNT do
        local r = client:get("/something", {
          headers = {
            ["X-Route"] = "Italy"
          }
        })

        assert.response(r).has.status(404)
      end

      local _, defaultRequestCount, defaultErrors = defaultServer:done()
      local _, alternateRequestCount, alternateErrors = alternateServer:done()

      -- verify
      assert.same({0, 0}, {defaultRequestCount, defaultErrors})
      assert.same({0, 0}, {alternateRequestCount, alternateErrors})

    end)
  end)

end

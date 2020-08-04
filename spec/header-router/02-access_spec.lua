local helpers = require "spec.helpers"
local bu = require "spec.fixtures.balancer_utils"

local PLUGIN_NAME = "header-router"
local REQUEST_COUNT = 1
local ROUTE_PATH = "/local"
local ALTERNATE_ROUTE_PATH = "/alternate"

for _, strategy in helpers.each_strategy() do
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()

    local client
    local default_port
    local alternate_port
    local default_server
    local alternate_server

    lazy_setup(function()

      local bp = helpers.get_db_utils(strategy, nil, { PLUGIN_NAME })

      local europe_upstream = bp.upstreams:insert({
        name = "europe_cluster"
      })

      default_port = bu.add_target(bp, europe_upstream.id, "127.0.0.1")

      local italy_upstream = bp.upstreams:insert({
        name = "italy_cluster"
      })

      alternate_port = bu.add_target(bp, italy_upstream.id, "127.0.0.1")

      local default_service = bp.services:insert {
        protocol = "http",
        name = "dafault_service",
        host = "europe_cluster"
      }

      bp.routes:insert({
        paths = {ROUTE_PATH},
        service = {id = default_service.id}
      })

      local alternate_service = bp.services:insert {
        protocol = "http",
        name = "alternate_service",
        host = "europe_cluster"
      }

      bp.routes:insert({
        paths = {ALTERNATE_ROUTE_PATH},
        service = {id = alternate_service.id}
      })

      bp.plugins:insert {
        name = PLUGIN_NAME,
        service = { id = default_service.id },
        config = {
          rules = {
            { condition = {["X-Country"] = "Italy", ["X-Regione"] = "Abruzzo"}, upstream_name = "italy_cluster" },
          }
        },
      }

      bp.plugins:insert {
        name = PLUGIN_NAME,
        service = { id = alternate_service.id },
        config = {
          rules = {
            { condition = {["X-Country"] = "Italy", ["X-Regione"] = "Umbria"}, upstream_name = "europe_cluster"},
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
      default_server =  bu.http_server("127.0.0.1", default_port, {REQUEST_COUNT}, "false", "http")
      alternate_server = bu.http_server("127.0.0.1", alternate_port, {REQUEST_COUNT}, "false", "http")

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
        local _, default_request_count, default_errors_count = default_server:done()
        local _, alternate_request_count, alternate_errors = alternate_server:done()

        -- verify
        assert.same({REQUEST_COUNT, 0}, {default_request_count, default_errors_count})
        assert.same({0, 0}, {alternate_request_count, alternate_errors})

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

      local _, default_request_count, default_errors_count = default_server:done()
      local _, alternate_request_count, alternate_errors = alternate_server:done()

      -- verify
      assert.same({0, 0}, {default_request_count, default_errors_count})
      assert.same({REQUEST_COUNT, 0}, {alternate_request_count, alternate_errors})


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

      local _, default_request_count, default_errors_count = default_server:done()
      local _, alternate_request_count, alternate_errors = alternate_server:done()

      -- verify
      assert.same({REQUEST_COUNT, 0}, {default_request_count, default_errors_count})
      assert.same({0, 0}, {alternate_request_count, alternate_errors})


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

      local _, default_request_count, default_errors_count = default_server:done()
      local _, alternate_request_count, alternate_errors = alternate_server:done()

      -- verify
      assert.same({0, 0}, {default_request_count, default_errors_count})
      assert.same({0, 0}, {alternate_request_count, alternate_errors})

    end)

    it("matching works not only for the first rule", function()

      for i=1,REQUEST_COUNT do
        local r = client:get(ALTERNATE_ROUTE_PATH, {
          headers = {
            ["X-Country"] = "Italy", ["X-Regione"] = "Abruzzo"
          }
        })

        assert.response(r).has.status(200)
      end

      -- collect server results; hitcount
      local _, default_request_count, default_errors_count = default_server:done()
      local _, alternate_request_count, alternate_errors = alternate_server:done()

      -- verify
      assert.same({0, 0}, {default_request_count, default_errors_count})
      assert.same({REQUEST_COUNT, 0}, {alternate_request_count, alternate_errors})

    end)
  end)

end

local helpers = require "spec.helpers"
local bu = require "spec.fixtures.balancer_utils"


local PLUGIN_NAME = "header-router"
local REQUEST_COUNT = 1
local KEY = "kong"
local LOCAL_ROUTE_PATH = "/local"
local ALTERNATE_ROUTE_PATH = "/alternate"
local ANOTHER_ROUTE_PATH = "/another"
local CONSUMER_ROUTE_PATH = "/userspecific"
local UNROUTED_PATH = "/unrouted"
local DISABLE_DETAILED_LOGS = "false"


for _, strategy in helpers.each_strategy() do
  describe(PLUGIN_NAME .. ": (access) [#" .. strategy .. "]", function()

    local client
    local default_port
    local alternate_port
    local default_server
    local alternate_server
    local consumer

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
        name = "default_service",
        host = "europe_cluster"
      }
      
      local alternate_service = bp.services:insert {
        protocol = "http",
        name = "alternate_service",
        host = "europe_cluster"
      }
      
      local another_service = bp.services:insert {
        protocol = "http",
        name = "another_service",
        host = "europe_cluster"
      }
      
      local consumer_service = bp.services:insert {
        protocol = "http",
        name = "consumer_service",
        host = "europe_cluster"
      }

      bp.routes:insert({
        paths = {ALTERNATE_ROUTE_PATH},
        service = {id = alternate_service.id}
      })
    
      bp.routes:insert({
        paths = {LOCAL_ROUTE_PATH},
        service = {id = default_service.id}
      })
     
      bp.routes:insert({
        paths = {CONSUMER_ROUTE_PATH},
        service = {id = consumer_service.id},
      })

      local another_route = bp.routes:insert({
        paths   = {ANOTHER_ROUTE_PATH},
        service = {id = another_service.id}
      })
    
      local consumer_route = bp.routes:insert({
        paths   = {CONSUMER_ROUTE_PATH},
        service = {id = another_service.id}
      })
     
      consumer = bp.consumers:insert {
        username = "dawid"
      }
      
      
      bp.keyauth_credentials:insert {
        key      = KEY,
        consumer = { id = consumer.id },
      }
    
      bp.plugins:insert {
        name     = "key-auth",
        route = { id = consumer_route.id },
      }
    
      bp.plugins:insert {
        name = PLUGIN_NAME,
        consumer = { id = consumer.id },
        config = {
          rules = {
            { condition = {["X-Country"] = "Italy", ["X-Regione"] = "Abruzzo"}, upstream_name = "italy_cluster" },
          }
        },
      }

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
      
      bp.plugins:insert {
        name = PLUGIN_NAME,
        route = { id = another_route.id },
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

      -- Mock servers based on Balancer Utils HTTP Server - simple and good enough
      -- to test if correct upstream is hit
      default_server =  bu.http_server("127.0.0.1", default_port, {REQUEST_COUNT}, 
        DISABLE_DETAILED_LOGS, "http")
      alternate_server = bu.http_server("127.0.0.1", alternate_port, {REQUEST_COUNT}, 
        DISABLE_DETAILED_LOGS, "http")

    end)

    after_each(function()
      if client then client:close() end
    end)
  
    local function assert_default_routing(path, params) 
      for i=1,REQUEST_COUNT do
          local r = client:get(path, {
            headers = params.headers
          })

          assert.response(r).has.status(params.expected_reponse_status)
        end

        local _, default_request_count, default_errors_count = 
        default_server:done()
        local _, alternate_request_count, alternate_errors = 
        alternate_server:done()

        -- verify
        assert.same({REQUEST_COUNT, 0}, {default_request_count, default_errors_count})
        assert.same({0, 0}, {alternate_request_count, alternate_errors})
    end 
    
    local function assert_no_routing(path, params) 
      for i=1,REQUEST_COUNT do
          local r = client:get(path, {
            headers = params.headers
          })

          assert.response(r).has.status(params.expected_reponse_status)
        end

        local _, default_request_count, default_errors_count = 
        default_server:done()
        local _, alternate_request_count, alternate_errors = 
        alternate_server:done()

        -- verify
        assert.same({0, 0}, {default_request_count, default_errors_count})
        assert.same({0, 0}, {alternate_request_count, alternate_errors})
    end 
    

    describe("Default upstream routing ", function()
        
      it("defaults if routing header is not set", function()
        
        assert_default_routing(LOCAL_ROUTE_PATH, {
              headers = {},
              expected_reponse_status = 200
        })

      end)
        
      it("defaults if rule is matched partially", function()
          
        assert_default_routing(LOCAL_ROUTE_PATH, {
              headers = {["X-Country"] = "Italy"},
              expected_reponse_status = 200
        })
      
      end)
    
      it("defaults if rule headers are set to unmatched values", function()
          
        assert_default_routing(LOCAL_ROUTE_PATH, {
              headers = {["X-Country"] = "Germany", ["X-Regione"] = "Abruzzo"},
              expected_reponse_status = 200
        })
        
     end)
  
      
    end)

    describe("Alternate upstream routing succeeds", function()
        
      
      it("if all rule headers are set", function()
        for i=1,REQUEST_COUNT do
          local r = client:get(LOCAL_ROUTE_PATH, {
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
  
      it("if all rule headers are set in different order", function()
        for i=1,REQUEST_COUNT do
          local r = client:get(LOCAL_ROUTE_PATH, {
            headers = {
              ["X-Regione"] = "Abruzzo", ["X-Country"] = "Italy"
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
  
      it("if more headers than required for a rule are set", function()
        for i=1,REQUEST_COUNT do
          local r = client:get(LOCAL_ROUTE_PATH, {
            headers = {
              ["X-Country"] = "Italy", ["host"] = "localhost", ["X-Regione"] = "Abruzzo",
              ["X-Forwader-For"] = nil
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

      -- RFC 7230
      it("if header names are matchable in a different case", function()
        for i=1,REQUEST_COUNT do
          local r = client:get(LOCAL_ROUTE_PATH, {
            headers = {
              ["X-country"] = "Italy", ["x-Regione"] = "Abruzzo"
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
      
      it("if plugin is enabled for a route", function()
        for i=1,REQUEST_COUNT do
          local r = client:get(ANOTHER_ROUTE_PATH, {
            headers = {
              ["X-Country"] = "Italy", ["host"] = "localhost", ["X-Regione"] = "Abruzzo",
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
  
      it("if plugin is enabled for a consumer", function()
        for i=1,REQUEST_COUNT do
          local r = client:post(CONSUMER_ROUTE_PATH, {
            headers = {
              ["X-Country"] = "Italy", ["host"] = "localhost", ["X-Regione"] = "Abruzzo",
              ["apikey"] = KEY
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
      


      it("if more than one rule is configured", function()

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

    describe("Erors: ", function()
        it("returns 404 for request not mapped by associated route", function()
          
        assert_no_routing(UNROUTED_PATH, {
              headers = {["X-Country"] = "Italy", ["X-Regione"] = "Abruzzo"},
              expected_reponse_status = 404
        })
    
      end)
    end)
  end)
end


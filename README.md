[![Build Status][badge-travis-image]][badge-travis-url]

# Kong header router plugin

Simple Kong plugin which overrides default service upstream if specific headers are set.

## Configuration

### Enable the plugin on a Service

To enable this plugin on a Service execute following request:

```bash
$ curl -X POST http://localhost:8001/services/{service_id}/plugins -d "name=header-router" \ 
  -H 'Content-Type: application/json' --data '{"name": "header-router", "config": {configuration}} 
```

Where:

**`{service}`**: the `id` or `name` of the Service that plugin configuration will target.

**`{configuration}`**: the configuration object described in the [Attributes](#attributes) section. 

### Enable the plugin on a Route

To enable this plugin on a route execute following request:

```bash
$ curl -X POST http://localhost:8001/routes/{route_id}/plugins -d "name=header-router"
  -H 'Content-Type: application/json' --data '{"name": "header-router", "config": {configuration}}
```

Where:

**`{route}`**: the `id` or `name` of the Route that plugin configuration will target.

**`{configuration}`**: the configuration object described in the [Attributes](#attributes) section.

### Enable the plugin on a Consumer

To enable this plugin on a consumer execute following request:

```bash
$ curl -X POST http://localhost:8001/consumers/{consumer}/plugins -d "name=header-router"
 -H 'Content-Type: application/json' --data '{"name": "header-router", "config": {configuration}}
```
Where:

**`{consumer}`**: the `id` or `username` of the Consumer that plugin configuration will target.

**`{configuration}`**: the configuration object described in the [Attributes](#attributes) section .

### Enable the plugin globally

This plugin can be enabled globally so it will be run on every request Kong handles.

```bash
$ curl -X POST http://localhost:8001/plugins -d "name=header-router" 
  -H 'Content-Type: application/json' --data '{"name": "header-router", "config": {configuration}}
```

### <a name="attributes"></a> Attributes

The table below lists plugin specific parameters which can be used in the configuration.

Please read the [Plugin Reference](https://getkong.org/docs/latest/admin-api/#add-plugin)
for more information.

Attribute                                  | Description
------------------------------------------:| ------------
`name`                                     | The name of the plugin to use, in this case: `header-router`
`config.rules`                             | The list of rules which will be matched by the plugin

#### Rules

Attribute                  | Description
---------------------------| -------------
`condition`                | List of headers name and value pairs
`upstream_name`            | Name of the upstream where traffic will be routed if condition is matched

A rule can consist of multiple header names and values, a request must containt all of the specified headers with the specified values to be matched by the rule.

## Example

Create a default upstream object:

```bash
$  curl -i -X POST http://localhost:8001/upstreams -d name=default.host.com
HTTP/1.1 201 Created
...
```

Add a target to the newly created upstream:

```bash
$ curl -i -X POST http://localhost:8001/upstreams/default.host.com/targets -d target=localhost:9001
...
HTTP/1.1 201 Created
```

<a name="create-service"></a>Create a service connected to the default upstream:

```bash
$ curl -i -X POST http://localhost:8001/services --data protocol=http --data host=default.host.com --data name=service 
...
HTTP/1.1 201 Created
```
Create a route associated with newly created service:

```bash
$  curl -i -X POST http://localhost:8001/routes  --data "paths[]=/" --data service.id={service_id}
...
HTTP/1.1 201 Created  
```
Where:

**`service_id`**: the `id` of newly created service, returned in a response to the [above](#create-service) request 

At this point all requests would be processed by default Kong routing mechanism, a local upstream server can be run to verify routing is working as intended. 

A local [Mockbin](https://github.com/Kong/mockbin#docker) server instance can be used for testing purposes:

```bash
$ docker run -d --name mockbin_redis redis
$ docker run -d -p 9001:8080 --link mockbin_redis:redis mashape/mockbin
```

Check if requests are forwarded to the newly created mockbin server:

```bash
$ curl -i  http://localhost:8000/request
...
HTTP/1.1 200 OK
X-Powered-By: mockbin

```

Create another instance of mockbin running on a different port:

```bash
$ docker run -d --name mockbin_alternate_redis redis
$ docker run -d -p 9002:8080 --link mockbin_alternate_redis:redis mashape/mockbin
```

Now an alternative upstream with corresponding target can be defined:

```bash
$  curl -i -X POST http://localhost:8001/upstreams -d name=alternate.host.com
...
HTTP/1.1 201 Created
...

$ curl -i -X POST http://localhost:8001/upstreams/alternate.host.com/targets -d target=localhost:9002
...
HTTP/1.1 201 Created
...
```

The plugin can be enabled for the service:

```bash
$ curl -i -X POST http://localhost:8001/services/service/plugins -H 'Content-Type: application/json' --data '{"name": "header-router", "config": {"rules":[{"condition": {"X-Country":"Italy"}, "upstream_name": "alternate.host.com"}]}}' curl -i -X POST http://localhost:8001/services/service/plugins -H 'Content-Type: application/json' --data '{"name": "header-router", "config": {"rules":[{"condition": {"X-Country":"Italy"}, "upstream_name": "alternate.host.com"}]}}'
...
HTTP/1.1 201 Created
```

From now on requests with a **X-Country** header value set to **Italy** will be forwarded to the **alternate.host.com** upstream (which for the purpose of this example leads to localhost:9002 target): 

```bash
$ curl -i -H "X-Country: Italy" http://localhost:8000/request
...
HTTP/1.1 200 OK
...
{
...
  "headers": {
     ...
     "host": "localhost:9002"
   }
}
```



[badge-travis-url]: https://travis-ci.com/dgorniak/kong-header-router/branches
[badge-travis-image]: https://travis-ci.com/dgorniak/kong-header-router.svg?branch=master


<a name="readme-top"></a>

<div align="center">
    <img src="static/logo.png" alt="Logo" width="250" height="250">

  <h3 align="center">Lightbug API</h3>

  <p align="center">
    🐝 FastAPI-style HTTP APIs in Pure Mojo 🔥
    <br/>

   ![Written in Mojo][language-shield]
   [![MIT License][license-shield]][license-url]
   [![Contributors Welcome][contributors-shield]][contributors-url]
   [![Join our Discord][discord-shield]][discord-url]

  </p>
</div>

## Overview

Lightbug API is a FastAPI-inspired HTTP framework for Mojo. It uses Mojo's compile-time metaprogramming to give you ergonomic, typed route handlers with zero runtime overhead.

> **Not production-ready yet.** We're tracking Mojo's rapid development — breaking changes may occur.

## Features

- **Declarative routing** — `GET`, `POST`, `PUT`, `DELETE`, `PATCH` route builders
- **Typed handlers** — return your model directly; the framework auto-serialises it as JSON
- **Resource controllers** — one struct registers all five CRUD routes
- **Middleware** — request/response pipeline with short-circuit support
- **Path & query parameters** — typed extraction with defaults
- **JSON body parsing** — deserialise request bodies into typed structs
- **Sub-routers** — mount route groups under a shared prefix
- **Lifecycle hooks** — run code once before the server starts

---

## Getting Started

### Installation

Add the `mojo-community` channel and `lightbug_api` to your `pixi.toml`:

```toml
[workspace]
channels = [
  "conda-forge",
  "https://conda.modular.com/max",
  "https://repo.prefix.dev/mojo-community",
]

[dependencies]
lightbug_api = ">=0.1.1"
```

Then run:

```sh
pixi install
```

### Minimal example

```mojo
from lightbug_api import App, GET, POST, HandlerResponse
from lightbug_api.context import Context
from lightbug_api.response import Response
from lightbug_http.http.json import JsonSerializable, JsonDeserializable

@fieldwise_init
struct Item(JsonSerializable, Movable, Defaultable):
    var id: Int
    var name: String
    var price: Float64
    fn __init__(out self): self.id = 0; self.name = ""; self.price = 0.0

@fieldwise_init
struct CreateItemRequest(JsonDeserializable, Movable, Defaultable):
    var name: String
    var price: Float64
    fn __init__(out self): self.name = ""; self.price = 0.0

fn list_items(ctx: Context) raises -> Item:
    return Item(1, "Widget", 9.99)

fn create_item(ctx: Context) raises -> HandlerResponse:
    var body = ctx.json[CreateItemRequest]()
    return Response.created(Item(100, body.name, body.price))

fn main() raises:
    var app = App(
        GET[Item, list_items]("/items"),
        POST("/items", create_item),
    )
    app.run()
```

```sh
pixi run mojo main.mojo
curl http://localhost:8080/items
# {"id":1,"name":"Widget","price":9.99}
```

---

## Routing

### Typed handlers

Handlers that return a model type are **auto-serialised as JSON 200 OK** — no `Response.json()` call needed. Use Mojo's compile-time parameters to register them:

```mojo
fn get_item(ctx: Context) raises -> Item:
    var id = ctx.param("id", 0)
    return Item(id, String("Item ", id), 9.99)

GET[Item, get_item]("/items/{id}")
```

For handlers that need a non-200 status code, return `HandlerResponse` explicitly:

```mojo
fn create_item(ctx: Context) raises -> HandlerResponse:
    var body = ctx.json[CreateItemRequest]()
    return Response.created(Item(100, body.name, body.price))   # 201 Created

fn delete_item(ctx: Context) raises -> HandlerResponse:
    return Response.no_content()                                # 204 No Content
```

### Declarative app

```mojo
var app = App(
    GET[Item, list_items]("/items"),
    GET[Item, get_item]("/items/{id}"),
    POST("/items",        create_item),
    PUT[Item, update_item]("/items/{id}"),
    DELETE("/items/{id}", delete_item),
    mount("v1",
        GET[StatusResponse, health]("status"),
    ),
)
app.run()
```

### Resource controllers

Implement the `Resource` trait on a struct to group all five CRUD handlers. One call registers all five routes:

```mojo
struct Items(Resource):
    @staticmethod
    fn index(ctx: Context) raises -> HandlerResponse:    # GET /items
        return Response.json(Item(1, "Widget", 9.99))

    @staticmethod
    fn show(ctx: Context) raises -> HandlerResponse:     # GET /items/{id}
        return Response.json(Item(ctx.param("id", 0), "Widget", 9.99))

    @staticmethod
    fn create(ctx: Context) raises -> HandlerResponse:   # POST /items
        return Response.created(Item(1, "new", 0.0))

    @staticmethod
    fn update(ctx: Context) raises -> HandlerResponse:   # PUT /items/{id}
        return Response.json(Item(ctx.param("id", 0), "updated", 0.0))

    @staticmethod
    fn destroy(ctx: Context) raises -> HandlerResponse:  # DELETE /items/{id}
        return Response.no_content()

var app = App(resource[Items]("items"))
app.run()
# → GET /items  GET /items/{id}  POST /items  PUT /items/{id}  DELETE /items/{id}
```

### Path & query parameters

```mojo
fn get_item(ctx: Context) raises -> Item:
    var id      = ctx.param("id", 0)          # Int  (inferred from default)
    var verbose = ctx.query("verbose", False)  # Bool (inferred from default)
    var search  = ctx.query("q", "")          # String
    ...
```

`ctx.param` reads path params (`{id}` in the route pattern); `ctx.query` reads query string params. The type is inferred from the default value — no explicit casting needed.

### JSON body parsing

```mojo
@fieldwise_init
struct CreateItemRequest(JsonDeserializable, Movable, Defaultable):
    var name: String
    var price: Float64
    fn __init__(out self): self.name = ""; self.price = 0.0

fn create_item(ctx: Context) raises -> HandlerResponse:
    var body = ctx.json[CreateItemRequest]()
    # body.name, body.price are ready to use
    return Response.created(Item(1, body.name, body.price))
```

---

## Middleware

Middleware runs before every handler in registration order. Return `next()` to continue or `abort(response)` to short-circuit.

```mojo
from lightbug_api import MiddlewareResult, next, abort

fn require_auth(ctx: Context) raises -> MiddlewareResult:
    if not ctx.header("Authorization"):
        return abort(Response.unauthorized("missing Authorization header"))
    return next()

fn log_requests(ctx: Context) raises -> MiddlewareResult:
    print(ctx.method(), ctx.path())
    return next()

var app = App(...)
app.use(log_requests)
app.use(require_auth)
app.run()
```

---

## Response helpers

```mojo
Response.json(value)           # 200 OK — application/json
Response.text("hello")         # 200 OK — text/plain
Response.html("<h1>hi</h1>")   # 200 OK — text/html
Response.created(value)        # 201 Created — application/json
Response.no_content()          # 204 No Content
Response.redirect("/new/path") # 302 Found
Response.bad_request("msg")    # 400
Response.unauthorized("msg")   # 401
Response.forbidden("msg")      # 403
Response.not_found("msg")      # 404
Response.unprocessable("msg")  # 422
Response.internal_error("msg") # 500
```

---

## Sub-routers

Group routes under a shared URL prefix with `mount`:

```mojo
var app = App(
    mount("v1",
        GET[StatusResponse, health]("status"),
        GET[Version, version]("version"),
    ),
    mount("v2",
        GET[StatusResponse, health_v2]("status"),
    ),
)
# → GET /v1/status  GET /v1/version  GET /v2/status
```

For dynamic registration, use the builder API:

```mojo
var v1 = Router("v1")
v1.get("status", health)
app.add_router(v1^)
```

---

## Lifecycle hooks & error handling

```mojo
fn connect_db() raises:
    print("connecting to database...")

fn my_error_handler(ctx: Context, e: Error) raises -> HTTPResponse:
    print("unhandled error:", String(e))
    return Response.internal_error(String(e))

var app = App(...)
app.on_startup(connect_db)
app.on_error(my_error_handler)
app.run()
```

---

## Running

```sh
# development
pixi run mojo main.mojo

# compiled binary
pixi run mojo build main.mojo -o server
./server

# custom host / port
app.run(host="127.0.0.1", port=9090)
```

---

<!-- MARKDOWN LINKS & IMAGES -->
[language-shield]: https://img.shields.io/badge/language-mojo-orange
[license-shield]: https://img.shields.io/github/license/saviorand/lightbug_http?logo=github
[license-url]: https://github.com/saviorand/lightbug_http/blob/main/LICENSE
[contributors-shield]: https://img.shields.io/badge/contributors-welcome!-blue
[contributors-url]: https://github.com/saviorand/lightbug_http#contributing
[discord-shield]: https://img.shields.io/discord/1192127090271719495?style=flat&logo=discord&logoColor=white
[discord-url]: https://discord.gg/VFWETkTgrr

## Contributors

Want your name to show up here? See [CONTRIBUTING.md](./CONTRIBUTING.md)!

<a href="https://github.com/saviorand/lightbug_api/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=saviorand/lightbug_api" />
</a>

<sub>Made with [contrib.rocks](https://contrib.rocks).</sub>

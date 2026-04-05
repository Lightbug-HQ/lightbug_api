# lightbug_api showcase
# ─────────────────────────────────────────────────────────────────────────────
# Run:  mojo lightbug.mojo
# Test: curl http://localhost:8080/
#       curl http://localhost:8080/items
#       curl http://localhost:8080/items/42
#       curl "http://localhost:8080/items/42?verbose=true"
#       curl -X POST http://localhost:8080/items \
#            -H 'Content-Type: application/json' \
#            -d '{"name":"Widget","price":9.99}'
#       curl -X PUT http://localhost:8080/items/42 \
#            -H 'Content-Type: application/json' \
#            -d '{"name":"Updated","price":19.99}'
#       curl -X DELETE http://localhost:8080/items/42
#       curl http://localhost:8080/v1/status
# ─────────────────────────────────────────────────────────────────────────────

from lightbug_api import App, GET, POST, PUT, DELETE, mount, HandlerResponse
from lightbug_api.context import Context
from lightbug_api.response import Response
from lightbug_http.http.json import JsonSerializable, JsonDeserializable


# ----------------------------------------------------------------- data types

@fieldwise_init
struct Item(JsonSerializable, Movable, Defaultable):
    var id: Int
    var name: String
    var price: Float64

    fn __init__(out self):
        self.id = 0
        self.name = ""
        self.price = 0.0


@fieldwise_init
struct CreateItemRequest(JsonDeserializable, Movable, Defaultable):
    var name: String
    var price: Float64

    fn __init__(out self):
        self.name = ""
        self.price = 0.0


@fieldwise_init
struct StatusResponse(JsonSerializable, Movable, Defaultable):
    var status: String
    var version: String

    fn __init__(out self):
        self.status = ""
        self.version = ""


# ------------------------------------------------------------------ handlers

fn index(ctx: Context) raises -> HandlerResponse:
    return Response.text("Welcome to lightbug_api 🔥")


fn list_items(ctx: Context) raises -> HandlerResponse:
    return Response.json(Item(1, "Widget", 9.99))


fn get_item(ctx: Context) raises -> HandlerResponse:
    # ctx.param("id", 0)          → Int   (path param, typed by default value)
    # ctx.query("verbose", False) → Bool  (query param, typed by default value)
    var id      = ctx.param("id", 0)
    var verbose = ctx.query("verbose", False)

    if verbose:
        print("GET /items/", id, " (verbose mode)")

    return Response.json(Item(id, String("Item ", id), 9.99))


fn create_item(ctx: Context) raises -> HandlerResponse:
    var body    = ctx.json[CreateItemRequest]()
    var created = Item(100, body.name, body.price)
    return Response.created(created)


fn update_item(ctx: Context) raises -> HandlerResponse:
    var body = ctx.json[CreateItemRequest]()
    var id   = ctx.param("id", 0)
    return Response.json(Item(id, body.name, body.price))


fn delete_item(ctx: Context) raises -> HandlerResponse:
    var id = ctx.param("id", 0)
    print("Deleting item", id)
    return Response.no_content()


fn health(ctx: Context) raises -> HandlerResponse:
    return Response.json(StatusResponse("ok", "1.0.0"))


# --------------------------------------------------------------------- main

fn main() raises:
    var app = App(
        GET("/",              index),
        GET("/items",         list_items),
        GET("/items/{id}",    get_item),
        POST("/items",        create_item),
        PUT("/items/{id}",    update_item),
        DELETE("/items/{id}", delete_item),
        mount("v1",
            GET("status", health),
        ),
    )
    app.run()

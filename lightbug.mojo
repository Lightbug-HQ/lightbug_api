# lightbug_api showcase — metaprogramming ergonomics demo
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
#       curl http://localhost:8080/notes
#       curl http://localhost:8080/notes/1
# ─────────────────────────────────────────────────────────────────────────────

from lightbug_api import App, GET, POST, PUT, DELETE, mount, HandlerResponse, Resource, resource
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


@fieldwise_init
struct Note(JsonSerializable, Movable, Defaultable):
    var id: Int
    var text: String

    fn __init__(out self):
        self.id = 0
        self.text = ""


# ------------------------------------------------------------------ handlers
# Handlers that need full control (non-200 status, redirects, plain text) keep
# the HandlerResponse return type.  Handlers that just return a model use the
# model type directly — the framework auto-serialises as JSON 200 OK.

fn index(ctx: Context) raises -> HandlerResponse:
    return Response.text("Welcome to lightbug_api 🔥")


# ── Before (old style) ───────────────────────────────────────────────────────

fn list_items(ctx: Context) raises -> Item:          # ← returns Item directly
    return Item(1, "Widget", 9.99)


fn get_item(ctx: Context) raises -> Item:            # ← returns Item directly
    var id      = ctx.param("id", 0)
    var verbose = ctx.query("verbose", False)
    if verbose:
        print("GET /items/", id, " (verbose mode)")
    return Item(id, String("Item ", id), 9.99)


fn create_item(ctx: Context) raises -> HandlerResponse:
    # Still HandlerResponse — needs 201 Created status code
    var body    = ctx.json[CreateItemRequest]()
    var created = Item(100, body.name, body.price)
    return Response.created(created)


fn update_item(ctx: Context) raises -> Item:         # ← returns Item directly
    var body = ctx.json[CreateItemRequest]()
    var id   = ctx.param("id", 0)
    return Item(id, body.name, body.price)


fn delete_item(ctx: Context) raises -> HandlerResponse:
    # Still HandlerResponse — needs 204 No Content
    var id = ctx.param("id", 0)
    print("Deleting item", id)
    return Response.no_content()


fn health(ctx: Context) raises -> StatusResponse:    # ← returns StatusResponse directly
    return StatusResponse("ok", "1.0.0")


# ── Resource / controller pattern ────────────────────────────────────────────
# Group CRUD handlers in a struct; `resource[Notes]("notes")` registers all
# five standard routes under /notes in one call.

struct Notes(Resource):
    @staticmethod
    fn index(ctx: Context) raises -> HandlerResponse:
        return Response.json(Note(0, "all notes"))

    @staticmethod
    fn show(ctx: Context) raises -> HandlerResponse:
        var id = ctx.param("id", 0)
        return Response.json(Note(id, String("note ", id)))

    @staticmethod
    fn create(ctx: Context) raises -> HandlerResponse:
        return Response.created(Note(1, "new note"))

    @staticmethod
    fn update(ctx: Context) raises -> HandlerResponse:
        var id = ctx.param("id", 0)
        return Response.json(Note(id, "updated"))

    @staticmethod
    fn destroy(ctx: Context) raises -> HandlerResponse:
        return Response.no_content()


# --------------------------------------------------------------------- main

fn main() raises:
    var app = App(
        # Plain-text response — HandlerResponse (unchanged)
        GET("/",              index),

        # Typed return — framework auto-serialises Item as JSON 200 OK
        GET[Item, list_items]("/items"),
        GET[Item, get_item]("/items/{id}"),

        # 201 Created — still HandlerResponse (needs explicit status)
        POST("/items",        create_item),

        # Typed return
        PUT[Item, update_item]("/items/{id}"),

        # 204 No Content — still HandlerResponse
        DELETE("/items/{id}", delete_item),

        mount("v1",
            # Typed return inside a mount
            GET[StatusResponse, health]("status"),
        ),

        # Resource controller — five routes registered in one line
        resource[Notes]("notes"),
    )
    app.run()

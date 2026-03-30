# lightbug_api showcase
# ─────────────────────────────────────────────────────────────────────────────
# Run:  mojo lightbug.mojo
# Test: curl http://localhost:8080/
#       curl http://localhost:8080/items
#       curl http://localhost:8080/items/42
#       curl http://localhost:8080/items/42?verbose=true
#       curl -X POST http://localhost:8080/items \
#            -H 'Content-Type: application/json' \
#            -d '{"name":"Widget","price":9.99}'
#       curl -X PUT http://localhost:8080/items/42 \
#            -H 'Content-Type: application/json' \
#            -d '{"name":"Updated","price":19.99}'
#       curl -X DELETE http://localhost:8080/items/42
#       curl http://localhost:8080/v1/status
# ─────────────────────────────────────────────────────────────────────────────

from lightbug_api import App, Router, HandlerResponse
from lightbug_api.context import Context
from lightbug_api.response import Response
from lightbug_http.http.json import JsonSerializable, JsonDeserializable


# ----------------------------------------------------------------- data types

@fieldwise_init
struct Item(JsonSerializable, Movable, Defaultable):
    """An item returned in API responses."""

    var id: Int
    var name: String
    var price: Float64

    fn __init__(out self):
        self.id = 0
        self.name = ""
        self.price = 0.0


@fieldwise_init
struct CreateItemRequest(JsonDeserializable, Movable, Defaultable):
    """JSON body expected for POST /items."""

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
    """GET /  — plain-text welcome message."""
    return Response.text("Welcome to lightbug_api 🔥")


fn list_items(ctx: Context) raises -> HandlerResponse:
    """GET /items  — return a hard-coded list as JSON."""
    # In a real app you'd query a database here.
    return Response.json(Item(1, "Widget", 9.99))


fn get_item(ctx: Context) raises -> HandlerResponse:
    """GET /items/{id}  — return one item by ID."""
    var id = ctx.path_param("id", "unknown")
    var verbose = ctx.query("verbose", "false")

    if verbose == "true":
        print("GET /items/", id, " (verbose mode)")

    return Response.json(Item(42, String("Item ", id), 9.99))


fn create_item(ctx: Context) raises -> HandlerResponse:
    """POST /items  — deserialize JSON body, return 201 Created."""
    var body = ctx.json[CreateItemRequest]()
    var created = Item(100, body.name, body.price)
    return Response.created(created)


fn update_item(ctx: Context) raises -> HandlerResponse:
    """PUT /items/{id}  — update an item."""
    var body = ctx.json[CreateItemRequest]()
    return Response.json(Item(42, body.name, body.price))


fn delete_item(ctx: Context) raises -> HandlerResponse:
    """DELETE /items/{id}  — delete an item, return 204 No Content."""
    var id = ctx.path_param("id", "0")
    print("Deleting item", id)
    return Response.no_content()


fn health(ctx: Context) raises -> HandlerResponse:
    """GET /v1/status  — health check mounted under the v1 sub-router."""
    return Response.json(StatusResponse("ok", "1.0.0"))


# --------------------------------------------------------------------- main

fn main() raises:
    var app = App()

    # Root
    app.get("/", index)

    # Items resource — all HTTP verbs
    app.get("/items",       list_items)
    app.get("/items/{id}",  get_item)
    app.post("/items",      create_item)
    app.put("/items/{id}",  update_item)
    app.delete("/items/{id}", delete_item)

    # Sub-router mounted at /v1
    var v1 = Router("v1")
    v1.get("status", health)
    app.add_router(v1^)

    app.run()

# lightbug_api — quick-start example
# ─────────────────────────────────────────────────────────────────────────────
# Run:  pixi run mojo lightbug.mojo
# Test: curl http://localhost:8080/items
#       curl http://localhost:8080/items/42
#       curl -X POST http://localhost:8080/items \
#            -H 'Content-Type: application/json' \
#            -d '{"name":"Widget","price":9.99}'
#       curl http://localhost:8080/notes
#       curl http://localhost:8080/notes/1
# ─────────────────────────────────────────────────────────────────────────────

from lightbug_api import App, GET, POST, PUT, DELETE, mount, HandlerResponse, Resource, resource
from lightbug_api.context import Context
from lightbug_api.response import Response
from lightbug_http.http.json import JsonSerializable, JsonDeserializable


# ── Models ────────────────────────────────────────────────────────────────────

@fieldwise_init
struct Item(JsonSerializable, Movable, Defaultable):
    var id: Int
    var name: String
    var price: Float64

    fn __init__(out self):
        self.id = 0; self.name = ""; self.price = 0.0


@fieldwise_init
struct CreateItemRequest(JsonDeserializable, Movable, Defaultable):
    var name: String
    var price: Float64

    fn __init__(out self):
        self.name = ""; self.price = 0.0


@fieldwise_init
struct Note(JsonSerializable, Movable, Defaultable):
    var id: Int
    var text: String

    fn __init__(out self):
        self.id = 0; self.text = ""


# ── Handlers — return your model directly, no Response.json() needed ──────────

fn list_items(ctx: Context) raises -> Item:
    return Item(1, "Widget", 9.99)


fn get_item(ctx: Context) raises -> Item:
    var id = ctx.param("id", 0)
    return Item(id, String("Item ", id), 9.99)


fn create_item(ctx: Context) raises -> HandlerResponse:
    var body = ctx.json[CreateItemRequest]()
    return Response.created(Item(100, body.name, body.price))  # 201 Created


fn update_item(ctx: Context) raises -> Item:
    var body = ctx.json[CreateItemRequest]()
    return Item(ctx.param("id", 0), body.name, body.price)


fn delete_item(ctx: Context) raises -> HandlerResponse:
    return Response.no_content()  # 204 No Content


# ── Resource controller — one struct registers all five CRUD routes ────────────

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
        return Response.json(Note(ctx.param("id", 0), "updated"))

    @staticmethod
    fn destroy(ctx: Context) raises -> HandlerResponse:
        return Response.no_content()


# ── App ───────────────────────────────────────────────────────────────────────

fn main() raises:
    var app = App(
        GET[Item, list_items]("/items"),
        GET[Item, get_item]("/items/{id}"),
        POST("/items",        create_item),
        PUT[Item, update_item]("/items/{id}"),
        DELETE("/items/{id}", delete_item),

        resource[Notes]("notes"),  # GET /notes, GET /notes/{id}, POST, PUT, DELETE
    )
    app.run()

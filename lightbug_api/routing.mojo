from lightbug_http import HTTPRequest, HTTPResponse, NotFound
from lightbug_api.service import not_found

struct APIRoute(CollectionElement):
    var path: String
    var method: String
    var handler: fn (HTTPRequest) -> HTTPResponse
    var operation_id: String

    fn __init__(out self):
        self.path = ""
        self.method = ""
        self.handler = not_found
        self.operation_id = ""

    fn __init__(out self, path: String, method: String, handler: fn (HTTPRequest) -> HTTPResponse, operation_id: String):
        self.path = path
        self.method = method
        self.handler = handler
        self.operation_id = operation_id

    fn __copyinit__(out self: APIRoute, existing: APIRoute):
        self.path = existing.path
        self.method = existing.method
        self.handler = existing.handler
        self.operation_id = existing.operation_id

    fn __moveinit__(out self: APIRoute, owned existing: APIRoute):
        self.path = existing.path^
        self.method = existing.method^
        self.handler = existing.handler
        self.operation_id = existing.operation_id^


@value
struct Router:
    var routes: List[APIRoute]

    fn __init__(out self):
        self.routes = List[APIRoute]()

    fn __copyinit__(out self: Router, existing: Router):
        self.routes = existing.routes

    fn __moveinit__(out self: Router, owned existing: Router):
        self.routes = existing.routes

    fn add_route(out self, path: String, method: String, handler: fn (HTTPRequest) -> HTTPResponse, operation_id: String):
        self.routes.append(APIRoute(path, method, handler, operation_id))

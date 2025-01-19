from lightbug_http import HTTPRequest, HTTPResponse, NotFound


alias allowed_methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]


@register_passable("trivial")
struct APIRoute[path: StringLiteral, method: StringLiteral, handler: fn (HTTPRequest) -> HTTPResponse]:
    fn __init__(out self):
        constrained[method in allowed_methods, "Invalid method"]()


struct Router[
    *routes: APIRoute,
]:
    fn __init__(out self):
        pass

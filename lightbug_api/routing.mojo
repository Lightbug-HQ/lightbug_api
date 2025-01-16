from lightbug_http import HTTPRequest, HTTPResponse, NotFound

alias allowed_methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]


@register_passable("trivial")
struct APIRoute[path: StringLiteral, method: StringLiteral, handler: fn (HTTPRequest) -> HTTPResponse]:
    fn __init__(out self):
        constrained[method in allowed_methods, "Invalid method"]()


@register_passable("trivial")
struct Router[
    path: StringLiteral, 
    method: StringLiteral, 
    handler: fn (HTTPRequest) -> HTTPResponse,
    //,
    *Routes: APIRoute[path, method, handler]
]:
    var routes: VariadicList[APIRoute[path, method, handler]]

    @always_inline
    fn __init__(inout self, *routes: APIRoute[path, method, handler]):
        self.routes = VariadicList(routes)

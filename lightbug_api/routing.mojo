from lightbug_http import HTTPRequest, HTTPResponse, NotFound


@register_passable("trivial")
struct APIRoute:
    var path: StringLiteral
    var method: StringLiteral
    var handler: fn (HTTPRequest) -> HTTPResponse

    fn __init__(out self, path: StringLiteral, method: StringLiteral, handler: fn (HTTPRequest) -> HTTPResponse):
        self.path = path
        self.method = method
        self.handler = handler


@register_passable("trivial")
struct Router[*Ts: APIRoute]:
    var routes: VariadicList[APIRoute]

    @always_inline
    fn __init__(inout self, routes: VariadicList[APIRoute]):
        self.routes = routes

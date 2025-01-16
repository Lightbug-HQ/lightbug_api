from lightbug_http import HTTPRequest, HTTPResponse, Server, NotFound
from lightbug_api.routing import Router, APIRoute

@register_passable("trivial")
struct App[*Ts: APIRoute, router: Router]:
    fn func(mut self, req: HTTPRequest) raises -> HTTPResponse:
        for route in router.routes:
            if route.path == req.uri.path and route.method == req.method:
                return route.handler(req)
        return NotFound(req.uri.path)

    fn start_server(inout self, address: StringLiteral = "0.0.0.0:8080") raises:
        var server = Server()
        server.listen_and_serve(address, self)

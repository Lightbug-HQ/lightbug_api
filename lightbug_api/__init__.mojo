from lightbug_http import HTTPRequest, HTTPResponse, Server
from lightbug_api.routing import (
    BaseRequest,
    FromReq,
    RootRouter,
    Router,
    HandlerResponse,
    JSONType,
    Handler,
)


struct App:
    var router: RootRouter

    def __init__(out self) raises:
        self.router = RootRouter()

    def get(mut self, path: String, handler: Handler) raises:
        self.router.get(path, handler)

    def post(mut self, path: String, handler: Handler) raises:
        self.router.post(path, handler)

    def add_router(mut self, var router: Router) raises -> None:
        self.router.add_router(router^)

    def start_server(mut self, address: String = "0.0.0.0:8080") raises:
        var server = Server()
        server.listen_and_serve(address, self.router)

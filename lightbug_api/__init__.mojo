from lightbug_http import HTTPRequest, HTTPResponse, Server
from lightbug_api.routing import (
    CoercedQueryDefinition,
    CoercedQueryDict,
    ParsableTypes,
    RootRouter,
    Router,
    HTTPHandler,
    QueryKeyTypePair,
)


@value
struct App:
    var router: RootRouter

    fn __init__(inout self) raises:
        self.router = RootRouter()

    fn get(
        inout self,
        path: String,
        handler: HTTPHandler,
    ) raises:
        self.router.get(path, handler)

    fn post(
        inout self,
        path: String,
        handler: HTTPHandler,
    ) raises:
        self.router.post(path, handler)

    fn add_router(inout self, owned router: Router) raises -> None:
        self.router.add_router(router)

    fn start_server(inout self, address: StringLiteral = "0.0.0.0:8080") raises:
        var server = Server()
        server.listen_and_serve(address, self.router)

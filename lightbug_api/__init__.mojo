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

    # fn func(self, req: HTTPRequest) raises -> HTTPResponse:
    #     return self.router.func(req)

    fn get(
        inout self,
        path: String,
        handler: HTTPHandler,
        query_definition: CoercedQueryDefinition = CoercedQueryDefinition(),
    ) raises:
        self.router.get(path, handler, query_definition)

    fn post(
        inout self,
        path: String,
        handler: HTTPHandler,
        query_definition: CoercedQueryDefinition = CoercedQueryDefinition(),
    ) raises:
        self.router.post(path, handler, query_definition)

    fn add_router(inout self, owned router: Router) raises -> None:
        self.router.add_router(router)

    fn start_server(inout self, address: StringLiteral = "0.0.0.0:8080") raises:
        var server = Server()
        server.listen_and_serve(address, self.router)

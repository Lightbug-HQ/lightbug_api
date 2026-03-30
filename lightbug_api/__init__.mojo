from lightbug_http import HTTPRequest, HTTPResponse, Server
from lightbug_api.context import Context
from lightbug_api.response import Response
from lightbug_api.routing import (
    BaseRequest,
    FromReq,
    Handler,
    HandlerResponse,
    PathPattern,
    RouteMatch,
    RootRouter,
    Router,
)


struct App:
    """The top-level application — register routes then call ``run()``.

    Example::

        fn main() raises:
            var app = App()

            app.get("/",              index)
            app.get("/users/{id}",    get_user)
            app.post("/users",        create_user)
            app.delete("/users/{id}", delete_user)

            var api = Router("v1")
            api.get("status", health)
            app.add_router(api^)     # mounts at /v1/status

            app.run()
    """

    var router: RootRouter

    def __init__(out self) raises:
        self.router = RootRouter()

    # ------------------------------------------ route registration

    def get(mut self, path: String, handler: Handler) raises:
        """Register a GET handler."""
        self.router.get(path, handler)

    def post(mut self, path: String, handler: Handler) raises:
        """Register a POST handler."""
        self.router.post(path, handler)

    def put(mut self, path: String, handler: Handler) raises:
        """Register a PUT handler."""
        self.router.put(path, handler)

    def delete(mut self, path: String, handler: Handler) raises:
        """Register a DELETE handler."""
        self.router.delete(path, handler)

    def patch(mut self, path: String, handler: Handler) raises:
        """Register a PATCH handler."""
        self.router.patch(path, handler)

    def options(mut self, path: String, handler: Handler) raises:
        """Register an OPTIONS handler."""
        self.router.options(path, handler)

    def head(mut self, path: String, handler: Handler) raises:
        """Register a HEAD handler."""
        self.router.head(path, handler)

    def add_router(mut self, var router: Router) raises -> None:
        """Mount a sub-router under its path fragment."""
        self.router.add_router(router^)

    # ------------------------------------------ start server

    def run(mut self, host: String = "0.0.0.0", port: Int = 8080) raises:
        """Start the HTTP server.

        Args:
            host: Bind address (default ``0.0.0.0``).
            port: TCP port (default ``8080``).
        """
        var server = Server()
        server.listen_and_serve(String(host, ":", port), self.router)

    def start_server(mut self, address: String = "0.0.0.0:8080") raises:
        """Start the HTTP server.

        Deprecated: use ``run(host, port)`` instead.
        """
        var server = Server()
        server.listen_and_serve(address, self.router)

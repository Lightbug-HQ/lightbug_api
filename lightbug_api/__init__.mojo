from lightbug_http import HTTPRequest, HTTPResponse, Server
from lightbug_api.context import Context
from lightbug_api.response import Response
from lightbug_api.routing import (
    BaseRequest,
    ErrorHandler,
    FromReq,
    Handler,
    HandlerResponse,
    Middleware,
    MiddlewareEntry,
    MiddlewareResult,
    PathPattern,
    Route,
    RouteMatch,
    RootRouter,
    Router,
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    OPTIONS,
    HEAD,
    mount,
    abort,
    next,
    _apply_routes,
)


# ---------------------------------------------------------- startup hook types

comptime StartupHook = fn () raises

struct StartupHookEntry(Copyable):
    var hook: StartupHook

    fn __init__(out self, hook: StartupHook):
        self.hook = hook

    fn __init__(out self, *, copy: Self):
        self.hook = copy.hook


# ----------------------------------------------------------------------- App

struct App:
    """The top-level application — register routes then call ``run()``.

    **Declarative style** (recommended)::

        fn main() raises:
            App(
                GET("/",              index),
                GET("/users/{id}",    get_user),
                POST("/users",        create_user),
                DELETE("/users/{id}", delete_user),
                mount("v1",
                    GET("status", health),
                ),
            ).run()

    **Builder style** (for dynamic or conditional registration)::

        fn main() raises:
            var app = App()
            app.get("/",           index)
            app.post("/users",     create_user)
            app.use(require_auth)
            app.on_startup(connect_db)
            app.on_error(my_error_handler)
            app.run()
    """

    var router: RootRouter
    var startup_hooks: List[StartupHookEntry]

    def __init__(out self) raises:
        """Create an empty app for use with the builder style."""
        self.router = RootRouter()
        self.startup_hooks = List[StartupHookEntry]()

    def __init__(out self, *routes: Route) raises:
        """Create an app from a declarative list of Route specs.

        Example::

            App(
                GET("/",       index),
                POST("/items", create_item),
                mount("v1", GET("status", health)),
            ).run()
        """
        self.router = RootRouter()
        self.startup_hooks = List[StartupHookEntry]()
        var route_list = List[Route]()
        for i in range(len(routes)):
            route_list.append(routes[i].copy())
        _apply_routes[True](self.router, route_list)

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

    # ------------------------------------------ middleware

    def use(mut self, middleware: Middleware) -> None:
        """Add a middleware function that runs before every handler.

        Middleware runs in registration order. Use ``next()`` to continue to
        the next middleware / handler, or ``abort(response)`` to short-circuit.

        Example::

            fn log_requests(ctx: Context) raises -> MiddlewareResult:
                print(ctx.method(), ctx.path())
                return next()

            fn require_token(ctx: Context) raises -> MiddlewareResult:
                if not ctx.header("X-API-Key"):
                    return abort(Response.unauthorized("missing X-API-Key"))
                return next()

            app.use(log_requests)
            app.use(require_token)
        """
        self.router.use(middleware)

    # ------------------------------------------ lifecycle

    def on_startup(mut self, hook: StartupHook) -> None:
        """Register a function to run once before the server starts.

        Useful for opening database connections, loading config, etc.

        Example::

            fn connect_db() raises:
                print("DB connected")

            app.on_startup(connect_db)
        """
        self.startup_hooks.append(StartupHookEntry(hook))

    def on_error(mut self, handler: ErrorHandler) -> None:
        """Register a custom error handler for unhandled exceptions from handlers.

        The default handler logs the error and returns 500 Internal Server Error.

        Example::

            fn my_errors(ctx: Context, e: Error) raises -> HTTPResponse:
                print("Oops:", String(e))
                return Response.internal_error(String(e))

            app.on_error(my_errors)
        """
        self.router.error_handler = handler

    # ------------------------------------------ start server

    def run(mut self, host: String = "0.0.0.0", port: Int = 8080) raises:
        """Start the HTTP server.

        Runs all startup hooks, then begins listening for connections.

        Args:
            host: Bind address (default ``0.0.0.0``).
            port: TCP port (default ``8080``).
        """
        for i in range(len(self.startup_hooks)):
            self.startup_hooks[i].hook()
        var server = Server()
        server.listen_and_serve(String(host, ":", port), self.router)

    def start_server(mut self, address: String = "0.0.0.0:8080") raises:
        """Deprecated: use ``run(host, port)`` instead."""
        var server = Server()
        server.listen_and_serve(address, self.router)

from std.collections import Dict, List, Optional
from std.utils import Variant

from lightbug_http import HTTPRequest, HTTPResponse, HTTPService, NotFound, OK
from lightbug_http.http import RequestMethod
from lightbug_http.http.common_response import InternalError
from lightbug_http.uri import URIDelimiters

from lightbug_http import OK
from lightbug_http.http.json import Json

from lightbug_api.context import Context


# ------------------------------------------------------------------ constants

comptime MAX_SUB_ROUTER_DEPTH = 20


struct RouterErrors:
    comptime ROUTE_NOT_FOUND_ERROR = "ROUTE_NOT_FOUND_ERROR"
    comptime INVALID_PATH_ERROR = "INVALID_PATH_ERROR"
    comptime INVALID_PATH_FRAGMENT_ERROR = "INVALID_PATH_FRAGMENT_ERROR"


# ---------------------------------------------------------- public type aliases

# The two things a handler may return:
#   HTTPResponse  — full control (status, headers, body); use Response.* helpers
#   String        — auto-wrapped as 200 OK text/plain
comptime HandlerResponse = Variant[HTTPResponse, String]

# Every route handler shares this non-capturing function-pointer signature.
# Use Context to access the request, path params, query params, headers, body.
comptime Handler = fn (Context) raises -> HandlerResponse


# Compile-time adapter: specialises into a concrete Handler for any fn that
# returns a JSON-serialisable T.  Because `h` is a compile-time parameter the
# resulting specialisation has zero extra overhead vs writing the wrapper by hand.
fn _json_adapter[T: Movable & ImplicitlyDestructible, h: fn (Context) raises -> T](
    ctx: Context,
) raises -> HandlerResponse:
    return HandlerResponse(OK(Json(h(ctx))))


# ------------------------------------------------------------ middleware types

# Middleware return type:
#   HTTPResponse  — short-circuit: send this response immediately, skip handler
#   Bool          — continue to the next middleware / handler (value is ignored)
#
# Use the helpers ``next()`` and ``abort(response)`` to return these cleanly.
comptime MiddlewareResult = Variant[HTTPResponse, Bool]

# Every middleware shares this non-capturing function-pointer signature.
comptime Middleware = fn (Context) raises -> MiddlewareResult


fn next() -> MiddlewareResult:
    """Signal that processing should continue to the next middleware / handler."""
    return MiddlewareResult(True)


fn abort(var response: HTTPResponse) -> MiddlewareResult:
    """Short-circuit the request with *response*, skipping all further processing."""
    return MiddlewareResult(response^)


# Wrapper so Middleware function pointers can live in a List[MiddlewareEntry].
struct MiddlewareEntry(Copyable):
    var handler: Middleware

    fn __init__(out self, handler: Middleware):
        self.handler = handler

    fn __init__(out self, *, copy: Self):
        self.handler = copy.handler


# ------------------------------------------------------------ error handler

# Called when a route handler raises an unhandled error.
# Return an appropriate HTTPResponse; the exception is consumed.
comptime ErrorHandler = fn (Context, Error) raises -> HTTPResponse


fn _default_error_handler(ctx: Context, e: Error) raises -> HTTPResponse:
    print("lightbug_api error:", String(e))
    return InternalError()


# --------------------------------------------------------------- path matching

struct PathSegment(Copyable):
    """One segment of a URL pattern — either a literal or a ``{param}``."""

    var is_param: Bool
    var value: String  # literal text, or param name without braces

    fn __init__(out self, is_param: Bool, value: String):
        self.is_param = is_param
        self.value = value

    fn __init__(out self, *, copy: Self):
        self.is_param = copy.is_param
        self.value = copy.value


struct PathPattern(Copyable):
    """A compiled URL pattern that matches incoming paths and extracts params.

    Patterns use ``{name}`` placeholders::

        PathPattern.parse("/users/{id}/posts/{post_id}")

    Matching ``/users/42/posts/7`` produces ``{"id": "42", "post_id": "7"}``.
    """

    var segments: List[PathSegment]
    var raw: String

    fn __init__(out self, var segments: List[PathSegment], raw: String):
        self.segments = segments^
        self.raw = raw

    fn __init__(out self, *, copy: Self):
        self.segments = copy.segments.copy()
        self.raw = copy.raw

    @staticmethod
    fn parse(pattern: String) -> PathPattern:
        """Compile a URL pattern string into a ``PathPattern``.

        Args:
            pattern: Path pattern, e.g. ``/users/{id}`` or ``items``.

        Returns:
            A compiled ``PathPattern`` ready for matching.
        """
        var segments = List[PathSegment]()
        var path = pattern

        # Strip the leading slash so we work in the same space as the
        # partial_path strings the router passes around.
        if len(path) > 0 and path.startswith("/"):
            path = String(path[byte=1:])

        # Root / empty pattern has no segments.
        if len(path) == 0:
            return PathPattern(segments^, pattern)

        var parts = path.split("/")
        for i in range(len(parts)):
            var s = String(parts[i])
            if s.startswith("{") and s.endswith("}"):
                var name = String(s[byte=1 : len(s) - 1])
                segments.append(PathSegment(True, name))
            else:
                segments.append(PathSegment(False, s))

        return PathPattern(segments^, pattern)

    fn match(self, path: String) -> Optional[Dict[String, String]]:
        """Try to match *path* against this pattern.

        Args:
            path: Incoming path fragment (without the sub-router prefix).

        Returns:
            Extracted params dict on success, or ``None`` if no match.
        """
        var check_path = path
        if len(check_path) > 0 and check_path.startswith("/"):
            check_path = String(check_path[byte=1:])

        # Empty pattern matches empty (root) path.
        if len(self.segments) == 0:
            if len(check_path) == 0:
                return Optional(Dict[String, String]())
            return Optional[Dict[String, String]]()

        var parts = check_path.split("/")
        if len(parts) != len(self.segments):
            return Optional[Dict[String, String]]()

        var params = Dict[String, String]()
        for i in range(len(self.segments)):
            if self.segments[i].is_param:
                params[self.segments[i].value] = String(parts[i])
            elif self.segments[i].value != String(parts[i]):
                return Optional[Dict[String, String]]()

        return Optional(params^)


# ------------------------------------------------------- route entry / match

struct RouteEntry(Copyable):
    """A single registered route: HTTP method + compiled pattern + handler."""

    var method: String
    var pattern: PathPattern
    var handler: Handler

    fn __init__(
        out self,
        method: String,
        var pattern: PathPattern,
        handler: Handler,
    ):
        self.method = method
        self.pattern = pattern^
        self.handler = handler

    fn __init__(out self, *, copy: Self):
        self.method = copy.method
        self.pattern = copy.pattern.copy()
        self.handler = copy.handler


struct RouteMatch(Copyable):
    """The result of a successful route lookup."""

    var handler: Handler
    var path_params: Dict[String, String]

    fn __init__(out self, handler: Handler, var path_params: Dict[String, String]):
        self.handler = handler
        self.path_params = path_params^

    fn __init__(out self, *, copy: Self):
        self.handler = copy.handler
        self.path_params = copy.path_params.copy()


# ----------------------------------------------------------- backwards compat

trait FromReq(Copyable, ImplicitlyDestructible):
    """Retained for backwards compatibility."""

    def __init__(out self, request: HTTPRequest, json: Dict[String, String]):
        ...

    def from_request(mut self, req: HTTPRequest) raises -> Self:
        ...

    def __str__(self) -> String:
        ...


struct BaseRequest(FromReq):
    var request: HTTPRequest
    var json: Dict[String, String]

    def __init__(out self, request: HTTPRequest, json: Dict[String, String]):
        self.request = request.copy()
        self.json = json.copy()

    def __init__(out self, *, copy: Self):
        self.request = copy.request.copy()
        self.json = copy.json.copy()

    def __str__(self) -> String:
        return ""

    def from_request(mut self, req: HTTPRequest) raises -> Self:
        return self.copy()


# --------------------------------------------------------------- router core

struct RouterBase[is_main_app: Bool = False](HTTPService, Copyable):
    """Generic router used for both the root app and mounted sub-routers.

    Route patterns support ``{param}`` path placeholders::

        router.get("/users/{id}", get_user)
        router.post("/users/{id}/comments", add_comment)

    Sub-routers group routes under a shared prefix::

        var v1 = Router("v1")
        v1.get("status", health_check)
        app.add_router(v1^)   # serves GET /v1/status
    """

    var path_fragment: String
    var sub_routers: List[RouterBase[False]]
    var routes: List[RouteEntry]
    var middleware: List[MiddlewareEntry]
    var error_handler: ErrorHandler

    # ------------------------------------------------------------------ init

    def __init__(out self: Self) raises:
        if not Self.is_main_app:
            raise Error("Sub-router requires a URL path fragment")
        self.path_fragment = "/"
        self.sub_routers = List[RouterBase[False]]()
        self.routes = List[RouteEntry]()
        self.middleware = List[MiddlewareEntry]()
        self.error_handler = _default_error_handler

    def __init__(out self: Self, path_fragment: String) raises:
        self.path_fragment = path_fragment
        self.sub_routers = List[RouterBase[False]]()
        self.routes = List[RouteEntry]()
        self.middleware = List[MiddlewareEntry]()
        self.error_handler = _default_error_handler

        if not self._validate_path_fragment(path_fragment):
            raise Error(RouterErrors.INVALID_PATH_FRAGMENT_ERROR)

    def __init__(out self, *, copy: Self):
        self.path_fragment = copy.path_fragment
        self.sub_routers = copy.sub_routers.copy()
        self.routes = copy.routes.copy()
        self.middleware = copy.middleware.copy()
        self.error_handler = copy.error_handler

    # -------------------------------------------------------- route registration

    def add_route(
        mut self,
        path: String,
        handler: Handler,
        method: RequestMethod,
    ) raises -> None:
        if not self._validate_path(path):
            raise Error(RouterErrors.INVALID_PATH_ERROR)
        self.routes.append(RouteEntry(method.value, PathPattern.parse(path), handler))

    def get(mut self, path: String, handler: Handler) raises:
        """Register a GET handler for *path*."""
        self.add_route(path, handler, materialize[RequestMethod.get]())

    def post(mut self, path: String, handler: Handler) raises:
        """Register a POST handler for *path*."""
        self.add_route(path, handler, materialize[RequestMethod.post]())

    def put(mut self, path: String, handler: Handler) raises:
        """Register a PUT handler for *path*."""
        self.add_route(path, handler, materialize[RequestMethod.put]())

    def delete(mut self, path: String, handler: Handler) raises:
        """Register a DELETE handler for *path*."""
        self.add_route(path, handler, materialize[RequestMethod.delete]())

    def patch(mut self, path: String, handler: Handler) raises:
        """Register a PATCH handler for *path*."""
        self.add_route(path, handler, materialize[RequestMethod.patch]())

    def options(mut self, path: String, handler: Handler) raises:
        """Register an OPTIONS handler for *path*."""
        self.add_route(path, handler, materialize[RequestMethod.options]())

    def head(mut self, path: String, handler: Handler) raises:
        """Register a HEAD handler for *path*."""
        self.add_route(path, handler, materialize[RequestMethod.head]())

    def add_router(mut self, var router: RouterBase[False]) raises -> None:
        """Mount a sub-router, nesting all its routes under its path fragment."""
        self.sub_routers.append(router^)

    def use(mut self, middleware: Middleware) -> None:
        """Add a middleware function that runs before every handler on this router.

        Middleware runs in registration order. Return ``next()`` to continue,
        or ``abort(response)`` to short-circuit.

        Example::

            fn require_auth(ctx: Context) raises -> MiddlewareResult:
                if not ctx.header("Authorization"):
                    return abort(Response.unauthorized())
                return next()

            app.use(require_auth)
        """
        self.middleware.append(MiddlewareEntry(middleware))

    # ---------------------------------------------------------------- dispatch

    def func(mut self, req: HTTPRequest) raises -> HTTPResponse:
        """``HTTPService`` entry point — route the request and return a response."""
        var path = String(req.uri.path.split(URIDelimiters.PATH, 1)[1])
        var route_match: RouteMatch
        try:
            route_match = self._route(path, req.method)
        except e:
            if String(e) == RouterErrors.ROUTE_NOT_FOUND_ERROR:
                return NotFound(String(req.uri.path))
            raise e^

        var ctx = Context(req.copy(), route_match.path_params.copy())

        # Run middleware chain — any middleware may short-circuit with a response.
        for i in range(len(self.middleware)):
            var mw_result = self.middleware[i].handler(ctx)
            if mw_result.isa[HTTPResponse]():
                return mw_result.unsafe_take[HTTPResponse]()
            # else Bool → continue to next middleware / handler

        # Dispatch to the matched handler; convert unhandled errors to responses.
        var res: HandlerResponse
        try:
            res = route_match.handler(ctx)
        except e:
            return self.error_handler(ctx, e)

        return self._encode_response(res^)

    # --------------------------------------------------------------- internals

    def _route(
        mut self, partial_path: String, method: String, depth: Int = 0
    ) raises -> RouteMatch:
        if depth > MAX_SUB_ROUTER_DEPTH:
            raise Error(RouterErrors.ROUTE_NOT_FOUND_ERROR)

        var sub_router_name: String = ""
        var remaining_path: String = partial_path

        if partial_path:
            var fragments = partial_path.split(URIDelimiters.PATH, 1)
            sub_router_name = String(fragments[0])
            if len(fragments) == 2:
                remaining_path = String(fragments[1])
            else:
                remaining_path = ""

        # Exact sub-router prefix wins first.
        var sub_idx = self._find_sub_router(sub_router_name)
        if sub_idx:
            return self.sub_routers[sub_idx.value()]._route(
                remaining_path, method, depth + 1
            )

        # Then try pattern matching within this router.
        for i in range(len(self.routes)):
            if self.routes[i].method != method:
                continue
            var m = self.routes[i].pattern.match(partial_path)
            if m:
                var params = m.value().copy()
                return RouteMatch(self.routes[i].handler, params^)

        raise Error(RouterErrors.ROUTE_NOT_FOUND_ERROR)

    def _find_sub_router(self, name: String) -> Optional[Int]:
        for i in range(len(self.sub_routers)):
            if self.sub_routers[i].path_fragment == name:
                return Optional(i)
        return Optional[Int]()

    def _encode_response(self, var res: HandlerResponse) raises -> HTTPResponse:
        if res.isa[HTTPResponse]():
            return res.unsafe_take[HTTPResponse]()
        elif res.isa[String]():
            return OK(res[String])
        else:
            raise Error("Unsupported HandlerResponse variant")

    def _validate_path_fragment(self, path_fragment: String) -> Bool:
        return True

    def _validate_path(self, path: String) -> Bool:
        return True


comptime RootRouter = RouterBase[True]
comptime Router = RouterBase[False]


# ================================================================ Route DSL
# Declarative routing — pass Route values directly to App():
#
#   App(
#       GET("/",           index),
#       GET("/items/{id}", get_item),
#       POST("/items",     create_item),
#       mount("v1",
#           GET("status", health),
#       ),
#   ).run()

fn _no_op_handler(ctx: Context) raises -> HandlerResponse:
    """Sentinel handler for mount nodes — never called at runtime."""
    return HandlerResponse(String(""))


struct Route(Copyable):
    """A declarative route spec — either a leaf route or a sub-router mount.

    Create instances via the ``GET``, ``POST``, … and ``mount`` helpers.
    Pass them to ``App(...)`` for one-shot declarative registration::

        App(
            GET("/users",      list_users),
            POST("/users",     create_user),
            GET("/users/{id}", get_user),
            mount("v1",
                GET("status", health),
            ),
        ).run()
    """

    var method: String      # HTTP verb, or "MOUNT" for sub-router nodes
    var path: String        # route path  (leaf routes)
    var fragment: String    # mount prefix (mount nodes)
    var handler: Handler    # route handler; _no_op_handler for mounts
    var children: List[Route]

    fn __init__(out self, method: String, path: String, handler: Handler):
        self.method = method
        self.path = path
        self.fragment = ""
        self.handler = handler
        self.children = List[Route]()

    fn __init__(out self, fragment: String, var children: List[Route]):
        self.method = "MOUNT"
        self.path = ""
        self.fragment = fragment
        self.handler = _no_op_handler
        self.children = children^

    fn __init__(out self, *, copy: Self):
        self.method = copy.method
        self.path = copy.path
        self.fragment = copy.fragment
        self.handler = copy.handler
        self.children = copy.children.copy()


fn GET(path: String, handler: Handler) -> Route:
    """Declare a GET route."""
    return Route("GET", path, handler)


fn POST(path: String, handler: Handler) -> Route:
    """Declare a POST route."""
    return Route("POST", path, handler)


fn PUT(path: String, handler: Handler) -> Route:
    """Declare a PUT route."""
    return Route("PUT", path, handler)


fn DELETE(path: String, handler: Handler) -> Route:
    """Declare a DELETE route."""
    return Route("DELETE", path, handler)


fn PATCH(path: String, handler: Handler) -> Route:
    """Declare a PATCH route."""
    return Route("PATCH", path, handler)


fn OPTIONS(path: String, handler: Handler) -> Route:
    """Declare an OPTIONS route."""
    return Route("OPTIONS", path, handler)


fn HEAD(path: String, handler: Handler) -> Route:
    """Declare a HEAD route."""
    return Route("HEAD", path, handler)


fn mount(fragment: String, *children: Route) -> Route:
    """Declare a sub-router mounted at *fragment*.

    All child routes are served under the ``/<fragment>/`` prefix::

        mount("v1",
            GET("status",  health),
            GET("version", version),
        )
        # → GET /v1/status, GET /v1/version
    """
    var child_list = List[Route]()
    for i in range(len(children)):
        child_list.append(children[i].copy())
    return Route(fragment, child_list^)


fn _apply_routes[is_main: Bool](mut router: RouterBase[is_main], routes: List[Route]) raises:
    """Register a list of ``Route`` specs onto *router*, recursing into mounts."""
    for i in range(len(routes)):
        var r = routes[i].copy()
        if r.method == "MOUNT":
            var sub = RouterBase[False](r.fragment)
            _apply_routes[False](sub, r.children)
            router.add_router(sub^)
        else:
            router.add_route(r.path, r.handler, RequestMethod(r.method))


# ================================================================ Typed route builders
# Parametric overloads that let handlers return model types directly instead of
# wrapping everything in ``HandlerResponse``.  ``_json_adapter`` is specialised
# at compile time so there is zero runtime overhead over hand-written wrappers.
#
# Usage::
#
#   fn get_item(ctx: Context) raises -> Item:   # no Response.json() needed
#       return Item(ctx.param("id", 0), "Widget", 9.99)
#
#   GET[Item, get_item]("/items/{id}")           # T is often inferable

fn GET[T: Movable & ImplicitlyDestructible, h: fn (Context) raises -> T](path: String) -> Route:
    """GET route whose handler returns *T* directly — auto-serialised as JSON."""
    return Route("GET", path, _json_adapter[T, h])


fn POST[T: Movable & ImplicitlyDestructible, h: fn (Context) raises -> T](path: String) -> Route:
    """POST route whose handler returns *T* directly — auto-serialised as JSON."""
    return Route("POST", path, _json_adapter[T, h])


fn PUT[T: Movable & ImplicitlyDestructible, h: fn (Context) raises -> T](path: String) -> Route:
    """PUT route whose handler returns *T* directly — auto-serialised as JSON."""
    return Route("PUT", path, _json_adapter[T, h])


fn DELETE[T: Movable & ImplicitlyDestructible, h: fn (Context) raises -> T](path: String) -> Route:
    """DELETE route whose handler returns *T* directly — auto-serialised as JSON."""
    return Route("DELETE", path, _json_adapter[T, h])


fn PATCH[T: Movable & ImplicitlyDestructible, h: fn (Context) raises -> T](path: String) -> Route:
    """PATCH route whose handler returns *T* directly — auto-serialised as JSON."""
    return Route("PATCH", path, _json_adapter[T, h])


# ================================================================ Resource trait
# Declare a struct-based CRUD controller and register all five standard routes
# in one call::
#
#   struct Items(Resource):
#       @staticmethod
#       fn index(ctx: Context) raises -> HandlerResponse: ...
#       @staticmethod
#       fn show(ctx: Context) raises -> HandlerResponse: ...
#       @staticmethod
#       fn create(ctx: Context) raises -> HandlerResponse: ...
#       @staticmethod
#       fn update(ctx: Context) raises -> HandlerResponse: ...
#       @staticmethod
#       fn destroy(ctx: Context) raises -> HandlerResponse: ...
#
#   App(resource[Items]("items")).run()
#   # → GET /items, GET /items/{id}, POST /items, PUT /items/{id}, DELETE /items/{id}

trait Resource:
    """Struct-based CRUD resource controller.

    Implement all five static methods then register with ``resource[R](fragment)``.
    Static methods mean no instance is needed — the struct is purely a namespace.
    """

    @staticmethod
    fn index(ctx: Context) raises -> HandlerResponse:
        """GET /  — list all resources."""
        ...

    @staticmethod
    fn show(ctx: Context) raises -> HandlerResponse:
        """GET /{id}  — retrieve one resource."""
        ...

    @staticmethod
    fn create(ctx: Context) raises -> HandlerResponse:
        """POST /  — create a resource."""
        ...

    @staticmethod
    fn update(ctx: Context) raises -> HandlerResponse:
        """PUT /{id}  — replace a resource."""
        ...

    @staticmethod
    fn destroy(ctx: Context) raises -> HandlerResponse:
        """DELETE /{id}  — remove a resource."""
        ...


fn resource[R: Resource](fragment: String) -> Route:
    """Declare a full CRUD resource mounted at *fragment*.

    Equivalent to::

        mount(fragment,
            GET("",        R.index),
            GET("{id}",    R.show),
            POST("",       R.create),
            PUT("{id}",    R.update),
            DELETE("{id}", R.destroy),
        )
    """
    return mount(
        fragment,
        GET("",        R.index),
        GET("{id}",    R.show),
        POST("",       R.create),
        PUT("{id}",    R.update),
        DELETE("{id}", R.destroy),
    )

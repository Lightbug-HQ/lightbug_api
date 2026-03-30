from std.collections import Dict, List, Optional
from std.utils import Variant

from lightbug_http import HTTPRequest, HTTPResponse, HTTPService, NotFound, OK
from lightbug_http.http import RequestMethod
from lightbug_http.uri import URIDelimiters

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

    # ------------------------------------------------------------------ init

    def __init__(out self: Self) raises:
        if not Self.is_main_app:
            raise Error("Sub-router requires a URL path fragment")
        self.path_fragment = "/"
        self.sub_routers = List[RouterBase[False]]()
        self.routes = List[RouteEntry]()

    def __init__(out self: Self, path_fragment: String) raises:
        self.path_fragment = path_fragment
        self.sub_routers = List[RouterBase[False]]()
        self.routes = List[RouteEntry]()

        if not self._validate_path_fragment(path_fragment):
            raise Error(RouterErrors.INVALID_PATH_FRAGMENT_ERROR)

    def __init__(out self, *, copy: Self):
        self.path_fragment = copy.path_fragment
        self.sub_routers = copy.sub_routers.copy()
        self.routes = copy.routes.copy()

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
        var res = route_match.handler(ctx)
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

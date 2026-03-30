from std.utils import Variant
from std.collections import Dict, List, Optional

from lightbug_http import NotFound, OK, HTTPService, HTTPRequest, HTTPResponse
from lightbug_http.http import RequestMethod
from lightbug_http.uri import URIDelimiters

comptime MAX_SUB_ROUTER_DEPTH = 20


struct RouterErrors:
    comptime ROUTE_NOT_FOUND_ERROR = "ROUTE_NOT_FOUND_ERROR"
    comptime INVALID_PATH_ERROR = "INVALID_PATH_ERROR"
    comptime INVALID_PATH_FRAGMENT_ERROR = "INVALID_PATH_FRAGMENT_ERROR"


# TODO: Placeholder type, what can the JSON container look like
comptime JSONType = Dict[String, String]

comptime HandlerResponse = Variant[HTTPResponse, String, JSONType]

# All route handlers share this signature — plain non-capturing function pointer
comptime Handler = fn (HTTPRequest) raises -> HandlerResponse


# Utilities for organizing request extraction — not used by router dispatch
trait FromReq(Copyable, ImplicitlyDestructible):
    def __init__(out self, request: HTTPRequest, json: JSONType):
        ...

    def from_request(mut self, req: HTTPRequest) raises -> Self:
        ...

    def __str__(self) -> String:
        ...


struct BaseRequest(FromReq):
    var request: HTTPRequest
    var json: JSONType

    def __init__(out self, request: HTTPRequest, json: JSONType):
        self.request = request.copy()
        self.json = json.copy()

    def __init__(out self, *, copy: Self):
        self.request = copy.request.copy()
        self.json = copy.json.copy()

    def __str__(self) -> String:
        return ""

    def from_request(mut self, req: HTTPRequest) raises -> Self:
        return self.copy()


# Stores a single route entry: (method, path, handler)
struct RouteEntry(Copyable):
    var method: String
    var path: String
    var handler: Handler

    def __init__(
        out self,
        method: String,
        path: String,
        handler: Handler,
    ):
        self.method = method
        self.path = path
        self.handler = handler

    def __init__(out self, *, copy: Self):
        self.method = copy.method
        self.path = copy.path
        self.handler = copy.handler


struct RouterBase[is_main_app: Bool = False](HTTPService, Copyable):
    var path_fragment: String
    var sub_routers: List[RouterBase[False]]
    var routes: List[RouteEntry]

    def __init__(out self: Self) raises:
        if not Self.is_main_app:
            raise Error("Sub-router requires url path fragment it will manage")
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

    def _find_sub_router(self, name: String) -> Optional[Int]:
        for i in range(len(self.sub_routers)):
            if self.sub_routers[i].path_fragment == name:
                return Optional(i)
        return Optional[Int]()

    def _find_route(self, method: String, path: String) -> Optional[Int]:
        for i in range(len(self.routes)):
            if self.routes[i].method == method and self.routes[i].path == path:
                return Optional(i)
        return Optional[Int]()

    def _route(
        mut self, partial_path: String, method: String, depth: Int = 0
    ) raises -> Handler:
        if depth > MAX_SUB_ROUTER_DEPTH:
            raise Error(RouterErrors.ROUTE_NOT_FOUND_ERROR)

        var sub_router_name: String = ""
        var remaining_path: String = ""
        var handler_path = partial_path

        if partial_path:
            var fragments = partial_path.split(URIDelimiters.PATH, 1)
            sub_router_name = String(fragments[0])
            if len(fragments) == 2:
                remaining_path = String(fragments[1])
            else:
                remaining_path = ""
        else:
            handler_path = URIDelimiters.PATH

        var sub_router_idx = self._find_sub_router(sub_router_name)
        if sub_router_idx:
            return self.sub_routers[sub_router_idx.value()]._route(
                remaining_path, method, depth + 1
            )

        var route_idx = self._find_route(method, handler_path)
        if route_idx:
            return self.routes[route_idx.value()].handler

        raise Error(RouterErrors.ROUTE_NOT_FOUND_ERROR)

    def _encode_response(self, var res: HandlerResponse) raises -> HTTPResponse:
        if res.isa[HTTPResponse]():
            return res.unsafe_take[HTTPResponse]()
        elif res.isa[String]():
            return OK(res[String])
        elif res.isa[JSONType]():
            return OK(self._serialize_json(res[JSONType]))
        else:
            raise Error("Unsupported response type")

    def _serialize_json(self, json: JSONType) raises -> String:
        # TODO: Placeholder json serialize implementation
        var str_frags = List[String]()
        for kv in json.items():
            str_frags.append('"' + kv.key + '": "' + kv.value + '"')
        return "{" + String(",").join(str_frags) + "}"

    def func(mut self, req: HTTPRequest) raises -> HTTPResponse:
        var path = String(req.uri.path.split(URIDelimiters.PATH, 1)[1])
        var handler: Handler
        try:
            handler = self._route(path, req.method)
        except e:
            if String(e) == RouterErrors.ROUTE_NOT_FOUND_ERROR:
                return NotFound(String(req.uri.path))
            raise e^

        var res = handler(req)
        return self._encode_response(res^)

    def _validate_path_fragment(self, path_fragment: String) -> Bool:
        # TODO: Validate fragment
        return True

    def _validate_path(self, path: String) -> Bool:
        # TODO: Validate path
        return True

    def add_router(mut self, var router: RouterBase[False]) raises -> None:
        self.sub_routers.append(router^)

    def add_route(
        mut self,
        partial_path: String,
        handler: Handler,
        method: RequestMethod,
    ) raises -> None:
        if not self._validate_path(partial_path):
            raise Error(RouterErrors.INVALID_PATH_ERROR)
        self.routes.append(RouteEntry(method.value, partial_path, handler))

    def get(
        mut self,
        path: String,
        handler: Handler,
    ) raises:
        self.add_route(path, handler, materialize[RequestMethod.get]())

    def post(
        mut self,
        path: String,
        handler: Handler,
    ) raises:
        self.add_route(path, handler, materialize[RequestMethod.post]())


comptime RootRouter = RouterBase[True]
comptime Router = RouterBase[False]

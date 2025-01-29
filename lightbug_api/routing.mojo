from utils.variant import Variant
from collections import Dict, Optional
from collections.dict import _DictEntryIter

from lightbug_http import NotFound, OK, HTTPService, HTTPRequest, HTTPResponse
from lightbug_http.strings import RequestMethod

alias MAX_SUB_ROUTER_DEPTH = 20


struct RouterErrors:
    alias ROUTE_NOT_FOUND_ERROR = "ROUTE_NOT_FOUND_ERROR"
    alias INVALID_PATH_ERROR = "INVALID_PATH_ERROR"
    alias INVALID_PATH_FRAGMENT_ERROR = "INVALID_PATH_FRAGMENT_ERROR"


alias HTTPHandler = fn (req: HTTPRequest) -> HTTPResponse


@value
struct HandlerMeta:
    var handler: HTTPHandler


alias HTTPHandlersMap = Dict[String, HandlerMeta]


@value
struct RouterBase[is_main_app: Bool = False](HTTPService):
    var path_fragment: String
    var sub_routers: Dict[String, RouterBase[False]]
    var routes: Dict[String, HTTPHandlersMap]

    fn __init__(out self: Self) raises:
        if not is_main_app:
            raise Error("Sub-router requires url path fragment it will manage")
        self.__init__(path_fragment="/")

    fn __init__(out self: Self, path_fragment: String) raises:
        self.path_fragment = path_fragment
        self.sub_routers = Dict[String, RouterBase[False]]()
        self.routes = Dict[String, HTTPHandlersMap]()

        self.routes[RequestMethod.head.value] = HTTPHandlersMap()
        self.routes[RequestMethod.get.value] = HTTPHandlersMap()
        self.routes[RequestMethod.put.value] = HTTPHandlersMap()
        self.routes[RequestMethod.post.value] = HTTPHandlersMap()
        self.routes[RequestMethod.patch.value] = HTTPHandlersMap()
        self.routes[RequestMethod.delete.value] = HTTPHandlersMap()
        self.routes[RequestMethod.options.value] = HTTPHandlersMap()

        if not self._validate_path_fragment(path_fragment):
            raise Error(RouterErrors.INVALID_PATH_FRAGMENT_ERROR)

    fn _route(
        mut self, partial_path: String, method: String, depth: Int = 0
    ) raises -> HandlerMeta:
        if depth > MAX_SUB_ROUTER_DEPTH:
            raise Error(RouterErrors.ROUTE_NOT_FOUND_ERROR)

        var sub_router_name: String = ""
        var remaining_path: String = ""
        var handler_path = partial_path

        if partial_path:
            # TODO: (Hrist) Update to lightbug_http.uri.URIDelimiters.PATH when available
            var fragments = partial_path.split("/", 1)

            sub_router_name = fragments[0]
            if len(fragments) == 2:
                remaining_path = fragments[1]
            else:
                remaining_path = ""

        else:
            # TODO: (Hrist) Update to lightbug_http.uri.URIDelimiters.PATH when available
            handler_path = "/"

        if sub_router_name in self.sub_routers:
            return self.sub_routers[sub_router_name]._route(
                remaining_path, method, depth + 1
            )
        elif handler_path in self.routes[method]:
            return self.routes[method][handler_path]
        else:
            raise Error(RouterErrors.ROUTE_NOT_FOUND_ERROR)

    fn func(mut self, req: HTTPRequest) raises -> HTTPResponse:
        var uri = req.uri
        # TODO: (Hrist) Update to lightbug_http.uri.URIDelimiters.PATH when available
        var path = uri.path.split("/", 1)[1]
        var route_handler_meta: HandlerMeta
        try:
            route_handler_meta = self._route(path, req.method)
        except e:
            if str(e) == RouterErrors.ROUTE_NOT_FOUND_ERROR:
                return NotFound(uri.path)
            raise e

        return route_handler_meta.handler(req)

    fn _validate_path_fragment(self, path_fragment: String) -> Bool:
        # TODO: Validate fragment
        return True

    fn _validate_path(self, path: String) -> Bool:
        # TODO: Validate path
        return True

    fn add_router(mut self, owned router: RouterBase[False]) raises -> None:
        self.sub_routers[router.path_fragment] = router

    fn add_route(
        mut self,
        partial_path: String,
        handler: HTTPHandler,
        method: RequestMethod = RequestMethod.get,
    ) raises -> None:
        if not self._validate_path(partial_path):
            raise Error(RouterErrors.INVALID_PATH_ERROR)
        var handler_meta = HandlerMeta(handler)

        self.routes[method.value][partial_path] = handler_meta^

    fn get(
        inout self,
        path: String,
        handler: HTTPHandler,
    ) raises:
        self.add_route(path, handler, RequestMethod.get)

    fn post(
        inout self,
        path: String,
        handler: HTTPHandler,
    ) raises:
        self.add_route(path, handler, RequestMethod.post)


alias RootRouter = RouterBase[True]
alias Router = RouterBase[False]

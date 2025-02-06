from utils.variant import Variant
from collections import Dict, List, Optional
from collections.dict import _DictEntryIter

from lightbug_http import NotFound, OK, HTTPService, HTTPRequest, HTTPResponse
from lightbug_http.http import RequestMethod
from lightbug_http.uri import URIDelimiters

alias MAX_SUB_ROUTER_DEPTH = 20


struct RouterErrors:
    alias ROUTE_NOT_FOUND_ERROR = "ROUTE_NOT_FOUND_ERROR"
    alias INVALID_PATH_ERROR = "INVALID_PATH_ERROR"
    alias INVALID_PATH_FRAGMENT_ERROR = "INVALID_PATH_FRAGMENT_ERROR"


alias HTTPHandlerWrapper = fn (req: HTTPRequest) raises escaping -> HTTPResponse

# TODO: Placeholder type, what can the JSON container look like
alias JSONType = Dict[String, String]

alias HandlerResponse = Variant[HTTPResponse, String, JSONType]


trait FromReq(Movable, Copyable):
    fn __init__(out self, request: HTTPRequest, json: JSONType):
        ...

    fn from_request(mut self, req: HTTPRequest) raises -> Self:
        ...

    fn __str__(self) -> String:
        ...


@value
struct BaseRequest:
    var request: HTTPRequest
    var json: JSONType

    fn __init__(out self, request: HTTPRequest, json: JSONType):
        self.request = request
        self.json = json

    fn __str__(self) -> String:
        return str("")

    fn from_request(mut self, req: HTTPRequest) raises -> Self:
        return self


@value
struct RouteHandler[T: FromReq](CollectionElement):
    var handler: fn (T) raises -> HandlerResponse

    fn __init__(inout self, h: fn (T) raises -> HandlerResponse):
        self.handler = h

    fn _encode_response(self, res: HandlerResponse) raises -> HTTPResponse:
        if res.isa[HTTPResponse]():
            return res[HTTPResponse]
        elif res.isa[String]():
            return OK(res[String])
        elif res.isa[JSONType]():
            return OK(self._serialize_json(res[JSONType]))
        else:
            raise Error("Unsupported response type")

    fn _serialize_json(self, json: JSONType) raises -> String:
        # TODO: Placeholder json serialize implementation
        fn ser(j: JSONType) raises -> String:
            var str_frags = List[String]()
            for kv in j.items():
                str_frags.append(
                    '"' + str(kv[].key) + '": "' + str(kv[].value) + '"'
                )

            var str_res = str("{") + str(",").join(str_frags) + str("}")
            return str_res

        return ser(json)

    fn _deserialize_json(self, req: HTTPRequest) raises -> JSONType:
        # TODO: Placeholder json deserialize implementation
        return JSONType()

    fn handle(self, req: HTTPRequest) raises -> HTTPResponse:
        var payload = T(request=req, json=self._deserialize_json(req))
        payload = payload.from_request(req)
        var handler_response = self.handler(payload)
        return self._encode_response(handler_response^)


alias HTTPHandlersMap = Dict[String, HTTPHandlerWrapper]


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
    ) raises -> HTTPHandlerWrapper:
        if depth > MAX_SUB_ROUTER_DEPTH:
            raise Error(RouterErrors.ROUTE_NOT_FOUND_ERROR)

        var sub_router_name: String = ""
        var remaining_path: String = ""
        var handler_path = partial_path

        if partial_path:
            var fragments = partial_path.split(URIDelimiters.PATH, 1)

            sub_router_name = fragments[0]
            if len(fragments) == 2:
                remaining_path = fragments[1]
            else:
                remaining_path = ""

        else:
            handler_path = URIDelimiters.PATH

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
        var path = uri.path.split(URIDelimiters.PATH, 1)[1]
        var route_handler_meta: HTTPHandlerWrapper
        try:
            route_handler_meta = self._route(path, req.method)
        except e:
            if str(e) == RouterErrors.ROUTE_NOT_FOUND_ERROR:
                return NotFound(uri.path)
            raise e

        return route_handler_meta(req)

    fn _validate_path_fragment(self, path_fragment: String) -> Bool:
        # TODO: Validate fragment
        return True

    fn _validate_path(self, path: String) -> Bool:
        # TODO: Validate path
        return True

    fn add_router(mut self, owned router: RouterBase[False]) raises -> None:
        self.sub_routers[router.path_fragment] = router

    # fn register[T: FromReq](inout self, path: String, handler: fn(T) raises):
    #
    #     fn handle(req: Request) raises:
    #       RouteHandler[T](handler).handle(req)
    #
    #     self.routes[path] = handle
    #
    # fn route(self, path: String, req: Request) raises:
    #     if path in self.routes:
    #         self.routes[path](req)
    #     else:

    fn add_route[
        T: FromReq
    ](
        mut self,
        partial_path: String,
        handler: fn (T) raises -> HandlerResponse,
        method: RequestMethod = RequestMethod.get,
    ) raises -> None:
        if not self._validate_path(partial_path):
            raise Error(RouterErrors.INVALID_PATH_ERROR)

        fn handle(req: HTTPRequest) raises -> HTTPResponse:
            return RouteHandler[T](handler).handle(req)

        self.routes[method.value][partial_path] = handle^

    fn get[
        T: FromReq = BaseRequest
    ](
        inout self,
        path: String,
        handler: fn (T) raises -> HandlerResponse,
    ) raises:
        self.add_route[T](path, handler, RequestMethod.get)

    fn post[
        T: FromReq = BaseRequest
    ](
        inout self,
        path: String,
        handler: fn (T) raises -> HandlerResponse,
    ) raises:
        self.add_route[T](path, handler, RequestMethod.post)


alias RootRouter = RouterBase[True]
alias Router = RouterBase[False]

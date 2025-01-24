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


alias HTTPHandler = fn (
    req: HTTPRequest, queries: CoercedQueryDict
) raises -> HTTPResponse


@value
struct HandlerMeta:
    var handler: HTTPHandler
    var query_definition: CoercedQueryDefinition

    fn coerce_query(self, query_data: QueryMap) raises -> CoercedQueryDict:
        var coerced_queries = CoercedQueryDict()

        for query_meta in self.query_definition:
            var query_key = query_meta[].key
            var value_type = query_meta[].value_type
            if query_key in query_data:
                var coerced_value: AnyQueryType = NoneType()

                if value_type == ParsableTypes.Int:
                    coerced_value = atol(query_data[query_key])
                elif value_type == ParsableTypes.Float64:
                    coerced_value = atof(query_data[query_key])
                elif value_type == ParsableTypes.String:
                    coerced_value = query_data[query_key]
                elif value_type == ParsableTypes.Bool:
                    var query_item = query_data[query_key].lower()
                    coerced_value = query_item == "true" or not (
                        query_item == "false"
                    )
                elif value_type == ParsableTypes.NoneType:
                    var query_item = query_data[query_key].lower()
                    if query_item in ("", "nil", "null", "none"):
                        coerced_value = NoneType()
                    else:
                        raise Error("Can not coerce to NoneType")

                coerced_queries._data[query_key] = QueryValue(coerced_value)

        return coerced_queries^


alias HTTPHandlersMap = Dict[String, HandlerMeta]

alias AnyQueryType = Variant[Int, Float64, String, Bool, NoneType]


struct ParsableTypes:
    alias Int = 0
    alias Float64 = 1
    alias String = 2
    alias Bool = 3
    alias NoneType = 4


@value
struct QueryValue(CollectionElement):
    var value: AnyQueryType

    fn __init__(out self: Self, value: AnyQueryType) raises:
        self.value = value

    @always_inline
    fn __moveinit__(inout self, owned existing: Self):
        self.value = existing.value

    @always_inline
    fn __copyinit__(inout self, existing: Self):
        self.value = existing.value


@value
struct QueryKeyValuePair:
    var key: String
    var value: AnyQueryType


@value
struct _QueryDictEntryIter[dict_origin: Origin[False]]:
    var iter: _DictEntryIter[String, QueryValue, dict_origin, True]

    fn __iter__(self) -> Self:
        return self

    @always_inline
    fn __next__(
        mut self,
    ) -> QueryKeyValuePair:
        var kvpair = self.iter.__next__()[]
        return QueryKeyValuePair(kvpair.key, kvpair.value.value)

    @always_inline
    fn __has_next__(self) -> Bool:
        return self.iter.__has_next__()

    fn __len__(self) -> Int:
        return self.iter.__len__()


@value
struct CoercedQueryDict(CollectionElement):
    var _data: Dict[String, QueryValue]

    fn __init__(out self: Self) raises:
        self._data = Dict[String, QueryValue]()

    fn __getitem__(self, key: String) raises -> AnyQueryType:
        return self._data[key].value

    fn items(
        self,
    ) -> _QueryDictEntryIter[dict_origin = __origin_of(self._data)]:
        return _QueryDictEntryIter(self._data.items())


@value
struct QueryKeyTypePair(CollectionElement):
    var key: String
    var value_type: Int


alias CoercedQueryDefinition = List[QueryKeyTypePair]

# TODO: (Hristo) Remove if this functionality gets merged into `lightbug_http`
alias QueryMap = Dict[String, String]


struct QueryDelimiters:
    alias ITEM = "&"
    alias ITEM_ASSIGN = "="


struct URIDelimiters:
    alias PATH = "/"


fn query_str_to_dict(query_string: String) raises -> QueryMap:
    var queries = Dict[String, String]()
    var query_items = query_string.split(QueryDelimiters.ITEM)
    for item in query_items:
        var key_val = item[].split(QueryDelimiters.ITEM_ASSIGN, 1)

        if key_val[0]:
            queries[key_val[0]] = ""
            if len(key_val) == 2:
                queries[key_val[0]] = key_val[1]

    return queries^


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
        var route_handler_meta: HandlerMeta
        try:
            route_handler_meta = self._route(path, req.method)
        except e:
            if str(e) == RouterErrors.ROUTE_NOT_FOUND_ERROR:
                return NotFound(uri.path)
            raise e

        var coerced_queries = route_handler_meta.coerce_query(
            query_str_to_dict(uri.query_string)
        )

        return route_handler_meta.handler(req, coerced_queries)

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
        query_definition: CoercedQueryDefinition = CoercedQueryDefinition(),
    ) raises -> None:
        if not self._validate_path(partial_path):
            raise Error(RouterErrors.INVALID_PATH_ERROR)
        var handler_meta = HandlerMeta(handler, query_definition)

        self.routes[method.value][partial_path] = handler_meta^

    fn get(
        inout self,
        path: String,
        handler: HTTPHandler,
        query_definition: CoercedQueryDefinition = CoercedQueryDefinition(),
    ) raises:
        self.add_route(path, handler, RequestMethod.get, query_definition)

    fn post(
        inout self,
        path: String,
        handler: HTTPHandler,
        query_definition: CoercedQueryDefinition = CoercedQueryDefinition(),
    ) raises:
        self.add_route(path, handler, RequestMethod.post, query_definition)


alias RootRouter = RouterBase[True]
alias Router = RouterBase[False]

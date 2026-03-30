from std.collections import Dict, Optional

from lightbug_http import HTTPRequest
from lightbug_http.http.json import Value, json_decode


struct Context(Copyable):
    """Request context passed to every route handler.

    Wraps the raw HTTP request and provides ergonomic, typed access to:
    - Path parameters  (e.g. ``{id}`` in ``/users/{id}``)
    - Query parameters (e.g. ``?page=2``)
    - Request headers
    - JSON body deserialization

    Example::

        fn get_user(ctx: Context) raises -> HandlerResponse:
            var id   = ctx.path_param("id").value()
            var page = ctx.query("page", "1")
            var user = ctx.json[UserRequest]()
            return Response.json(UserResponse(id, user.name))
    """

    var request: HTTPRequest
    var path_params: Dict[String, String]

    # ------------------------------------------------------------------ init

    fn __init__(out self, var request: HTTPRequest):
        self.request = request^
        self.path_params = Dict[String, String]()

    fn __init__(
        out self,
        var request: HTTPRequest,
        var path_params: Dict[String, String],
    ):
        self.request = request^
        self.path_params = path_params^

    fn __init__(out self, *, copy: Self):
        self.request = copy.request.copy()
        self.path_params = copy.path_params.copy()

    # --------------------------------------------------------------- body

    fn json[T: Movable & ImplicitlyDestructible](self) raises -> T:
        """Deserialize the request body as JSON into a typed struct.

        Parameters:
            T: Target type conforming to ``Movable & ImplicitlyDestructible``.
               Types with non-trivial destructors should also conform to
               ``Defaultable``.

        Returns:
            The deserialized value.

        Raises:
            Error if the body is not valid JSON or does not match ``T``.
        """
        return json_decode[T](self.request)

    fn body_json(self) raises -> Value:
        """Parse the request body as an untyped JSON ``Value``.

        Returns:
            A parsed ``emberjson.Value`` (object, array, string, number, …).

        Raises:
            Error if the body is not valid JSON.
        """
        return json_decode(self.request)

    fn body_raw(self) -> String:
        """Return the raw request body as a ``String``."""
        return String(self.request.get_body())

    # ---------------------------------------------------------- path params

    fn path_param(self, name: String) -> Optional[String]:
        """Look up a path parameter by name.

        For a route registered as ``/users/{id}``, calling
        ``path_param("id")`` on a request to ``/users/42`` returns
        ``Optional("42")``.

        Args:
            name: Parameter name without braces.

        Returns:
            The captured value, or ``None`` if the key is absent.
        """
        for kv in self.path_params.items():
            if kv.key == name:
                return Optional(String(kv.value))
        return Optional[String]()

    fn path_param(self, name: String, default: String) -> String:
        """Look up a path parameter, falling back to *default* if absent.

        Args:
            name: Parameter name without braces.
            default: Value to return when the parameter is not present.

        Returns:
            The captured value or *default*.
        """
        var result = self.path_param(name)
        if result:
            return result.value()
        return default

    # --------------------------------------------------------- query params

    fn query(self, name: String) -> Optional[String]:
        """Look up a query parameter by name.

        For a request to ``/search?q=hello&page=2``,
        ``query("q")`` returns ``Optional("hello")``.

        Args:
            name: Query parameter name.

        Returns:
            The value, or ``None`` if the parameter is absent.
        """
        for kv in self.request.uri.queries.items():
            if kv.key == name:
                return Optional(String(kv.value))
        return Optional[String]()

    fn query(self, name: String, default: String) -> String:
        """Look up a query parameter, falling back to *default* if absent.

        Args:
            name: Query parameter name.
            default: Value to return when the parameter is not present.

        Returns:
            The value or *default*.
        """
        var result = self.query(name)
        if result:
            return result.value()
        return default

    # ---------------------------------------------------------------- headers

    fn header(self, name: String) -> Optional[String]:
        """Look up a request header by name.

        Args:
            name: Header name (use ``HeaderKey`` constants for correctness).

        Returns:
            The header value, or ``None`` if the header is absent.
        """
        var result = self.request.headers.get(name)
        if result:
            return Optional(result.value())
        return Optional[String]()

    # ---------------------------------------------------------- convenience

    fn method(self) -> String:
        """Return the HTTP method (``GET``, ``POST``, ``PUT``, …)."""
        return self.request.method

    fn path(self) -> String:
        """Return the request path (e.g. ``/users/42``)."""
        return self.request.uri.path

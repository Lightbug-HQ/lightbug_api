from lightbug_http import HTTPResponse, OK, NotFound, BadRequest
from lightbug_http.header import Header, HeaderKey, Headers
from lightbug_http.http.common_response import InternalError
from lightbug_http.http.json import Json
from lightbug_http.io.bytes import Bytes


struct Response:
    """HTTP response factory.

    A collection of static helpers for the most common response patterns.
    Every handler can return one of these directly as ``HandlerResponse``.

    Example::

        fn list_items(ctx: Context) raises -> HandlerResponse:
            return Response.json(ItemList(items))

        fn create_item(ctx: Context) raises -> HandlerResponse:
            var body = ctx.json[CreateItem]()
            return Response.created(Item(body.name))

        fn get_page(ctx: Context) raises -> HandlerResponse:
            return Response.html("<h1>Hello</h1>")
    """

    # ------------------------------------------------------------------ 2xx

    @staticmethod
    fn json[T: AnyType](value: T) -> HTTPResponse:
        """200 OK — serialize *value* as ``application/json``.

        Parameters:
            T: Any type supported by ``emberjson.serialize`` (i.e. conforming
               to ``JsonSerializable``).
        """
        return OK(Json(value))

    @staticmethod
    fn text(body: String) -> HTTPResponse:
        """200 OK — ``text/plain`` response."""
        return OK(body, "text/plain")

    @staticmethod
    fn html(body: String) -> HTTPResponse:
        """200 OK — ``text/html; charset=utf-8`` response."""
        return OK(body, "text/html; charset=utf-8")

    @staticmethod
    fn created[T: AnyType](value: T) -> HTTPResponse:
        """201 Created — serialize *value* as ``application/json``.

        Parameters:
            T: Any type supported by ``emberjson.serialize``.
        """
        var resp = HTTPResponse(Json(value)^)
        resp.status_code = 201
        resp.status_text = "Created"
        return resp^

    @staticmethod
    fn accepted[T: AnyType](value: T) -> HTTPResponse:
        """202 Accepted — serialize *value* as ``application/json``."""
        var resp = HTTPResponse(Json(value)^)
        resp.status_code = 202
        resp.status_text = "Accepted"
        return resp^

    @staticmethod
    fn no_content() -> HTTPResponse:
        """204 No Content — empty body."""
        return HTTPResponse(
            body_bytes=Bytes(),
            headers=Headers(Header(HeaderKey.CONTENT_TYPE, "text/plain")),
            status_code=204,
            status_text="No Content",
        )

    # ------------------------------------------------------------------ 3xx

    @staticmethod
    fn redirect(location: String) -> HTTPResponse:
        """302 Found — redirect to *location*."""
        return HTTPResponse(
            body_bytes=Bytes(),
            headers=Headers(
                Header(HeaderKey.LOCATION, location),
                Header(HeaderKey.CONTENT_TYPE, "text/plain"),
            ),
            status_code=302,
            status_text="Found",
        )

    @staticmethod
    fn permanent_redirect(location: String) -> HTTPResponse:
        """301 Moved Permanently — redirect to *location*."""
        return HTTPResponse(
            body_bytes=Bytes(),
            headers=Headers(
                Header(HeaderKey.LOCATION, location),
                Header(HeaderKey.CONTENT_TYPE, "text/plain"),
            ),
            status_code=301,
            status_text="Moved Permanently",
        )

    # ------------------------------------------------------------------ 4xx

    @staticmethod
    fn bad_request(msg: String = "Bad Request") -> HTTPResponse:
        """400 Bad Request."""
        return BadRequest(msg)

    @staticmethod
    fn unauthorized(msg: String = "Unauthorized") -> HTTPResponse:
        """401 Unauthorized."""
        return HTTPResponse(
            body_bytes=msg.as_bytes(),
            headers=Headers(Header(HeaderKey.CONTENT_TYPE, "text/plain")),
            status_code=401,
            status_text="Unauthorized",
        )

    @staticmethod
    fn forbidden(msg: String = "Forbidden") -> HTTPResponse:
        """403 Forbidden."""
        return HTTPResponse(
            body_bytes=msg.as_bytes(),
            headers=Headers(Header(HeaderKey.CONTENT_TYPE, "text/plain")),
            status_code=403,
            status_text="Forbidden",
        )

    @staticmethod
    fn not_found(msg: String = "Not Found") -> HTTPResponse:
        """404 Not Found."""
        return HTTPResponse(
            body_bytes=msg.as_bytes(),
            headers=Headers(Header(HeaderKey.CONTENT_TYPE, "text/plain")),
            status_code=404,
            status_text="Not Found",
        )

    @staticmethod
    fn method_not_allowed() -> HTTPResponse:
        """405 Method Not Allowed."""
        return HTTPResponse(
            body_bytes="Method Not Allowed".as_bytes(),
            headers=Headers(Header(HeaderKey.CONTENT_TYPE, "text/plain")),
            status_code=405,
            status_text="Method Not Allowed",
        )

    @staticmethod
    fn unprocessable(msg: String = "Unprocessable Entity") -> HTTPResponse:
        """422 Unprocessable Entity — validation failures."""
        return HTTPResponse(
            body_bytes=msg.as_bytes(),
            headers=Headers(Header(HeaderKey.CONTENT_TYPE, "text/plain")),
            status_code=422,
            status_text="Unprocessable Entity",
        )

    # ------------------------------------------------------------------ 5xx

    @staticmethod
    fn internal_error(msg: String = "Internal Server Error") -> HTTPResponse:
        """500 Internal Server Error."""
        return InternalError()

    @staticmethod
    fn not_implemented(msg: String = "Not Implemented") -> HTTPResponse:
        """501 Not Implemented."""
        return HTTPResponse(
            body_bytes=msg.as_bytes(),
            headers=Headers(Header(HeaderKey.CONTENT_TYPE, "text/plain")),
            status_code=501,
            status_text="Not Implemented",
        )

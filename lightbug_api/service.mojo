from lightbug_http import HTTPRequest, HTTPResponse, NotFound


@always_inline
fn not_found(req: HTTPRequest) -> HTTPResponse:
    return NotFound(req.uri.path)

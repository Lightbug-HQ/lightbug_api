from lightbug_api import (
    App,
    BaseRequest,
    FromReq,
    Router,
    HandlerResponse,
    JSONType,
)
from lightbug_http import HTTPRequest, HTTPResponse, OK


fn printer(req: HTTPRequest) raises -> HandlerResponse:
    print("Got a request on ", req.uri.path, " with method ", req.method)
    return OK(req.body_raw)

fn hello(req: HTTPRequest) raises -> HandlerResponse:
    return OK("Hello 🔥!")


fn nested(req: HTTPRequest) raises -> HandlerResponse:
    print("Handling route:", req.uri.path)
    # Returning a string will get marshaled to a proper `OK` response
    return req.uri.path


struct Payload(FromReq):
    var request: HTTPRequest
    var json: JSONType
    var a: Int

    def __init__(out self, request: HTTPRequest, json: JSONType):
        self.a = 1
        self.request = request.copy()
        self.json = json.copy()

    def __init__(out self, *, copy: Self):
        self.a = copy.a
        self.request = copy.request.copy()
        self.json = copy.json.copy()

    def __str__(self) -> String:
        return String(self.a)

    def from_request(mut self, req: HTTPRequest) raises -> Self:
        self.a = 2
        return self.copy()


fn custom_request_payload(req: HTTPRequest) raises -> HandlerResponse:
    var payload = Payload(request=req, json=JSONType())
    payload = payload.from_request(req)
    print(payload.a)

    # Returning a JSON as the response, this is a very limited placeholder for now
    var json_response = JSONType()
    json_response["a"] = String(payload.a)
    return json_response^


fn main() raises:
    var app = App()

    app.get("/", hello)

    app.get("custom/", custom_request_payload)

    app.post("/", printer)

    var nested_router = Router("nested")
    nested_router.get(path="all/echo/", handler=nested)
    app.add_router(nested_router^)

    app.start_server()

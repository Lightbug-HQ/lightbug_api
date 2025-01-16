from os import mkdir
from os.path import exists
from pathlib import Path
from sys.ffi import external_call
from lightbug_http import HTTPRequest, HTTPResponse, Server, NotFound
from lightbug_http.utils import logger
from emberjson import JSON, Array, Object, Value, to_string
from lightbug_api.openapi.generate import OpenAPIGenerator
from lightbug_api.routing import Router
from lightbug_api.docs import DocsApp


@value
struct App[docs_enabled: Bool = False]:
    var router: Router
    var lightbug_dir: Path

    fn __init__(out self) raises:
        self.router = Router()
        self.lightbug_dir = Path()

    fn set_lightbug_dir(mut self, lightbug_dir: Path):
        self.lightbug_dir = lightbug_dir

    fn func(mut self, req: HTTPRequest) raises -> HTTPResponse:
        if docs_enabled and req.uri.path == "/docs" and req.method == "GET":
            var openapi_spec = self.generate_openapi_spec()
            var docs = DocsApp(to_string(openapi_spec))
            return docs.func(req)
        for route_ptr in self.router.routes:
            var route = route_ptr[]
            if route.path == req.uri.path and route.method == req.method:
                return route.handler(req)
        return NotFound(req.uri.path)

    fn get(mut self, path: String, handler: fn (HTTPRequest) -> HTTPResponse, operation_id: String):
        self.router.add_route(path, "GET", handler, operation_id)

    fn post(mut self, path: String, handler: fn (HTTPRequest) -> HTTPResponse, operation_id: String):
        self.router.add_route(path, "POST", handler, operation_id)

    fn put(mut self, path: String, handler: fn (HTTPRequest) -> HTTPResponse, operation_id: String):
        self.router.add_route(path, "PUT", handler, operation_id)

    fn delete(mut self, path: String, handler: fn (HTTPRequest) -> HTTPResponse, operation_id: String):
        self.router.add_route(path, "DELETE", handler, operation_id)

    fn update_temporary_files(mut self) raises:
        var routes_obj = Object()
        var routes = List[Value]()

        for route_ptr in self.router.routes:
            var route = route_ptr[]
            var route_obj = Object()
            route_obj["path"] = route.path
            route_obj["method"] = route.method
            route_obj["handler"] = route.operation_id
            routes.append(route_obj)

        routes_obj["routes"] = Array.from_list(routes)
        var cwd = Path()
        var lightbug_dir = cwd / ".lightbug"
        self.set_lightbug_dir(lightbug_dir)

        if not exists(lightbug_dir):
            logger.info("Creating .lightbug directory")
            mkdir(lightbug_dir)

        with open((lightbug_dir / "routes.json"), "w") as f:
            f.write(to_string[pretty=True](routes_obj))

        var mojodoc_status = external_call["system", UInt8](
            "magic run mojo doc ./lightbug.🔥 -o " + str(lightbug_dir) + "/mojodoc.json"
        )
        if mojodoc_status != 0:
            logger.error("Failed to generate mojodoc.json")
            return

    fn generate_openapi_spec(self) raises -> JSON:
        var generator = OpenAPIGenerator()

        var mojo_doc_json = generator.read_mojo_doc(str(self.lightbug_dir / "mojodoc.json"))
        var router_metadata_json = generator.read_router_metadata(str(self.lightbug_dir / "routes.json"))

        var openapi_spec = generator.generate_spec(mojo_doc_json, router_metadata_json)
        generator.save_spec(openapi_spec, str(self.lightbug_dir / "openapi_spec.json"))
        return openapi_spec

    fn start_server(mut self, address: StringLiteral = "0.0.0.0:8080") raises:
        if docs_enabled:
            logger.info("API Docs ready at: " + "http://" + String(address) + "/docs")
        self.update_temporary_files()
        var server = Server()
        server.listen_and_serve(address, self)

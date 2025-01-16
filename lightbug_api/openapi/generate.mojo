from collections.dict import Dict
from emberjson import JSON, Value, Array, Object, ParseOptions, parse, to_string


struct OpenAPIGenerator:
    var tags: List[Value]

    fn __init__(out self):
        self.tags = List[Value]()

    fn __init__(out self, tags: List[Value]):
        self.tags = tags

    fn set_tags(mut self, tags: List[Value]):
        self.tags = tags

    fn create_paths(mut self, mojo_doc: JSON, router_metadata: JSON) raises -> JSON:
        var paths = JSON()
        var route_map = Dict[String, Tuple[String, String]]()
        var routes = router_metadata["routes"][Array]._data
        for i in range(len(routes)):
            var route = routes[i][Object]
            var handler = str(route["handler"]).strip('"')
            var path = route["path"][String].strip('"')
            var method = String(route["method"][String].strip('"')).lower()
            route_map[handler] = (String(path), method)

        for func in mojo_doc["decl"][Object]["functions"][Array]._data:
            var func_name = str(func[][Object]["name"]).strip('"')

            if func_name not in route_map:
                continue

            var route_info = route_map[func_name]
            var path = route_info.get[0][String]()
            var http_method = route_info.get[1][String]()

            var endpoint = self.create_endpoint(func[].object(), http_method)

            if paths.__contains__(path):
                var new_path_item = JSON()
                var existing_path_item = paths[path][Object]

                for key in existing_path_item._data.keys():
                    var existing_key = key[]
                    new_path_item[existing_key] = existing_path_item[existing_key]

                new_path_item[http_method] = endpoint.object()

                paths[path] = new_path_item.object()
            else:
                var path_item = JSON()
                path_item[http_method] = endpoint.object()
                paths[path] = path_item.object()

        return paths

    fn create_endpoint(mut self, function_data: JSON, http_method: String) raises -> JSON:
        var endpoint = JSON()
        var func_name = function_data["name"]
        endpoint["summary"] = String(str(func_name).strip('"')) + " endpoint"
        endpoint["operationId"] = func_name

        var responses = JSON()
        var response_200 = JSON()

        var overloads = Array(function_data["overloads"])._data

        var request_description = String("Request body")
        var response_description = String("Successful response")

        for i in range(len(overloads)):
            var overload = overloads[i][Array][0]  # first overload only for now
            if "returnsDoc" in overload[Object]._data:
                response_description = String(str(overload[Object]["returnsDoc"]).strip('"'))
            if "summary" in overload[Object]._data:
                endpoint["description"] = String(str(overload[Object]["summary"]).strip('"'))
            if "description" in overload[Object]._data and str(overload[Object]["description"]).__contains__("Tags:"):
                var description = str(overload[Object]["description"])
                var tags_part = description.split("Tags:")[1]
                var tags_str = String(tags_part.strip().rstrip('."'))
                var tags = tags_str.split(",")
                var tag_values = List[Value]()
                for tag in tags:
                    var stripped_tag = String(tag[].strip()).replace("\\n", "").replace("\\t", "").replace("\\r", "")
                    var cleaned_tag = stripped_tag.strip("  ")
                    tag_values.append(Value(str(cleaned_tag)))

                self.set_tags(tag_values)
                endpoint["tags"] = Array(tag_values)

            if "args" in overload[Object]._data:
                var args = Array(overload[Object]["args"])._data
                for i in range(len(args)):
                    var arg = args[0][Array][i][Object]
                    if "description" in arg._data:
                        request_description = String(str(arg["description"]).strip('"'))
            break

        response_200["description"] = response_description

        var content = JSON()
        var text_plain = JSON()
        var schema = JSON()
        schema["type"] = "string"

        text_plain["schema"] = schema.object()
        content["text/plain"] = text_plain.object()
        response_200["content"] = content.object()
        responses["200"] = response_200.object()
        endpoint["responses"] = responses.object()

        if http_method == "post":
            var request_body = JSON()
            request_body["required"] = True
            request_body["description"] = request_description

            var req_content = JSON()
            var req_text_plain = JSON()
            var req_schema = JSON()
            req_schema["type"] = "string"

            req_text_plain["schema"] = req_schema.object()
            req_content["text/plain"] = req_text_plain.object()
            request_body["content"] = req_content.object()
            endpoint["requestBody"] = request_body.object()

        return endpoint

    fn create_components_schema(self) raises -> JSON:
        var components = JSON()
        var schemas = JSON()

        # Define HTTPRequest schema
        var http_request = JSON()
        var request_properties = JSON()

        var body_raw = JSON()
        body_raw["type"] = "string"

        var uri = JSON()
        var uri_properties = JSON()
        var path = JSON()
        path["type"] = "string"
        uri_properties["path"] = path.object()
        uri["type"] = "object"
        uri["properties"] = uri_properties.object()

        var method = JSON()
        method["type"] = "string"

        request_properties["body_raw"] = body_raw.object()
        request_properties["uri"] = uri.object()
        request_properties["method"] = method.object()

        http_request["type"] = "object"
        http_request["properties"] = request_properties.object()

        # Define HTTPResponse schema
        var http_response = JSON()
        var response_properties = JSON()
        var body = JSON()
        body["type"] = "string"
        response_properties["body"] = body.object()

        http_response["type"] = "object"
        http_response["properties"] = response_properties.object()

        schemas["HTTPRequest"] = http_request.object()
        schemas["HTTPResponse"] = http_response.object()
        components["schemas"] = schemas.object()

        return components

    fn generate_spec(mut self, mojo_doc: JSON, router_metadata: JSON) raises -> JSON:
        var spec = JSON()

        spec["openapi"] = "3.0.0"

        var info = JSON()
        info["title"] = mojo_doc["decl"][Object]["name"]
        info["version"] = mojo_doc["version"]
        info["description"] = "API generated from Mojo documentation"

        spec["info"] = info.object()
        spec["paths"] = self.create_paths(mojo_doc, router_metadata).object()
        spec["components"] = self.create_components_schema().object()

        return spec

    fn read_mojo_doc(self, filename: String) raises -> JSON:
        with open(filename, "r") as mojo_doc:
            return parse[ParseOptions(fast_float_parsing=True)](mojo_doc.read())

    fn read_router_metadata(self, filename: String) raises -> JSON:
        with open(filename, "r") as router_metadata:
            return parse[ParseOptions(fast_float_parsing=True)](router_metadata.read())

    fn save_spec(self, spec: JSON, filename: String) raises:
        with open(filename, "w") as f:
            f.write(to_string[pretty=True](spec))

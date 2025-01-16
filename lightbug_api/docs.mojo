from lightbug_http import Server, HTTPRequest, HTTPResponse, OK
from lightbug_http.utils import logger


@value
struct DocsApp:
    var openapi_spec: String

    fn func(mut self, req: HTTPRequest) raises -> HTTPResponse:
        var html_response = String(
            """
        <!doctype html>
<html>
  <head>
    <title>Scalar API Reference</title>
    <meta charset="utf-8" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1" />
  </head>
  <body>
    <script
  id="api-reference"
  type="application/json">
  {}
</script>
<script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
</html>
        """
        ).format(self.openapi_spec)
        return OK(html_response, "text/html; charset=utf-8")

    fn set_openapi_spec(mut self, openapi_spec: String):
        self.openapi_spec = openapi_spec

    fn start_docs_server(mut self, address: StringLiteral = "0.0.0.0:8888") raises:
        logger.info("Starting docs at " + String(address))
        var server = Server()
        server.listen_and_serve(address, self)

<a name="readme-top"></a>

<!-- PROJECT LOGO -->
<br />
<div align="center">
    <img src="static/logo.png" alt="Logo" width="250" height="250">

  <h3 align="center">Lightbug API</h3>

  <p align="center">
    🐝 Author APIs in Pure Mojo 🔥
    <br/>

   ![Written in Mojo][language-shield]
   [![MIT License][license-shield]][license-url]
   [![Contributors Welcome][contributors-shield]][contributors-url]
   [![Join our Discord][discord-shield]][discord-url]
   

  </p>
</div>

## Overview

Lightbug API is a framework that allows to quickly write expressive APIs.

This is not production ready yet. We're aiming to keep up with new developments in Mojo, but it might take some time to get to a point when this is safe to use in real-world applications.

Lightbug API currently has the following features:
 - [x] Assign handlers on given routes with different methods (GET, POST, ...)

 ### Check Out These Mojo Libraries:

- Logging - [@toasty/stump](https://github.com/thatstoasty/stump)
- CLI and Terminal - [@toasty/prism](https://github.com/thatstoasty/prism), [@toasty/mog](https://github.com/thatstoasty/mog)
- Date/Time - [@mojoto/morrow](https://github.com/mojoto/morrow.mojo) and [@toasty/small-time](https://github.com/thatstoasty/small-time)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

Learn how to get up and running with Mojo on the [Modular website](https://www.modular.com/max/mojo).
Once you have a Mojo project set up locally,

1. Add the `mojo-community` channel to your `mojoproject.toml`, e.g:
   ```toml
   [project]
   channels = ["conda-forge", "https://conda.modular.com/max", "https://repo.prefix.dev/mojo-community"]
   ```
2. Add `lightbug_api` and `lightbug_http` in dependencies:
   ```toml
   [dependencies]
   lightbug_api = ">=0.1.0.dev2024092905"
   lightbug_http = ">=0.1.4"
   ```
3. Run `magic install` at the root of your project, where `mojoproject.toml` is located
4. Lightbug API should now be installed. You can import all the default imports at once, e.g:
    ```mojo
    from lightbug_api import *
    ```
    or import individual structs and functions, e.g. 
    ```mojo
    from lightbug_api.routing import Router
    ```
5. Create one or more handlers for your routes that satiisfy the `HTTPService` trait:
   ```mojo
   trait HTTPService:
    fn func(self, req: HTTPRequest) raises -> HTTPResponse:
        ...
   ```
   For example, to make a `Printer` service that prints some details about the request to console:
   ```mojo
    from lightbug_http import HTTPRequest, HTTPResponse, OK

    @always_inline
    fn printer(req: HTTPRequest) -> HTTPResponse:
            print("Got a request on ", req.uri.path, " with method ", req.method)
            return OK(req.body_raw)
   ```
6. Assign your handlers to routes and launch your app with `start_server()`:
   ```mojo
    from lightbug_api import App
    from lightbug_http import HTTPRequest, HTTPResponse, OK

    @always_inline
    fn printer(req: HTTPRequest) -> HTTPResponse:
            print("Got a request on ", req.uri.path, " with method ", req.method)
            return OK(req.body_raw)

    @always_inline
    fn hello(req: HTTPRequest) -> HTTPResponse:
            return OK("Hello 🔥!")

    fn main() raises:
        var app = App()

        app.get("/", hello, "hello")
        app.post("/printer", printer, "printer")

        app.start_server()
   ```
7. Excellent 😈. Your app is now listening on the selected port. 
   You've got yourself a pure-Mojo API! 🔥

## API Docs
Lightbug serves API docs for your app automatically at `/docs` by default.
To disable this, add the `docs_enabled=False` flag when creating a new app instance: `App(docs_enabled=False)`.
To describe your routes, add Mojo docstring annotations like below:

```mojo

@always_inline
fn printer(req: HTTPRequest) -> HTTPResponse:
        """Prints the request body and returns it.

        Args:
            req: Any arbitrary HTTP request with a body.

        Returns:
                HTTPResponse: 200 OK with the request body.
        """
        print("Got a request on ", req.uri.path, " with method ", req.method)
        return OK(req.body_raw)

@always_inline
fn hello(req: HTTPRequest) -> HTTPResponse:
        """Simple hello world function.

        Args:
            req: Any arbitrary HTTP request.

        Returns:
                HTTPResponse: 200 OK with a Hello World message.

        Tags:
                hello.
        """
        return OK("Hello 🔥!", "text/plain; charset=utf-8")

fn main() raises:
    var app = App()

    app.get("/", hello, "hello")
    app.post("/printer", printer, "printer")

    app.start_server()
```


<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[language-shield]: https://img.shields.io/badge/language-mojo-orange
[license-shield]: https://img.shields.io/github/license/saviorand/lightbug_http?logo=github
[license-url]: https://github.com/saviorand/lightbug_http/blob/main/LICENSE
[contributors-shield]: https://img.shields.io/badge/contributors-welcome!-blue
[contributors-url]: https://github.com/saviorand/lightbug_http#contributing
[discord-shield]: https://img.shields.io/discord/1192127090271719495?style=flat&logo=discord&logoColor=white
[discord-url]: https://discord.gg/VFWETkTgrr


## Contributors
Want your name to show up here? See [CONTRIBUTING.md](./CONTRIBUTING.md)!

<a href="https://github.com/saviorand/lightbug_api/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=saviorand/lightbug_api" />
</a>

<sub>Made with [contrib.rocks](https://contrib.rocks).</sub>
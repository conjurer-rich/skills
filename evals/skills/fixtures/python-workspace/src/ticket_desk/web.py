"""A stand-in for the web framework. We do not own this module; do not change it."""

import re
from collections.abc import Callable
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Request:
    method: str
    path: str
    body: bytes = b""
    params: dict[str, str] = field(default_factory=dict[str, str])


@dataclass(frozen=True)
class Response:
    status: int
    body: object = None


type Handler = Callable[[Request], Response]


class Router:
    def __init__(self) -> None:
        self._routes: list[tuple[str, re.Pattern[str], Handler]] = []

    def route(self, method: str, pattern: str) -> Callable[[Handler], Handler]:
        regex = re.compile("^" + re.sub(r"\{(\w+)\}", r"(?P<\1>[^/]+)", pattern) + "$")

        def register(handler: Handler) -> Handler:
            self._routes.append((method, regex, handler))
            return handler

        return register

    def handle(self, request: Request) -> Response:
        for method, regex, handler in self._routes:
            match = regex.match(request.path)
            if method == request.method and match:
                return handler(
                    Request(request.method, request.path, request.body, match.groupdict())
                )
        return Response(404)

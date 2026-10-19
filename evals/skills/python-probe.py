"""Structural facts about Python files, for python-assertions.js.

Run with the workspace's own interpreter (3.12, so PEP 695 syntax parses):

    uv run python -I python-probe.py <file> [<file> ...]

Prints one JSON object keyed by the path given. Standard library only. The
graders decide what a fact means; this script only reports what is there.
"""

import ast
import io
import json
import sys
import tokenize
from pathlib import Path

PRIORITY_MEMBERS = {"low", "normal", "high"}
VALIDATE_METHODS = {"model_validate", "model_validate_json", "validate_python", "validate_json"}
VALIDATOR_MARKERS = {"AfterValidator", "BeforeValidator", "WrapValidator", "PlainValidator"}


def text(node: ast.AST) -> str:
    return ast.unparse(node)


def names_in(node: ast.AST) -> set[str]:
    found: set[str] = set()
    for child in ast.walk(node):
        if isinstance(child, ast.Name):
            found.add(child.id)
        elif isinstance(child, ast.Attribute):
            found.add(child.attr)
        elif isinstance(child, ast.Constant) and isinstance(child.value, str):
            # String annotations ("Any", "dict[str, Any]") still name types.
            try:
                found |= names_in(ast.parse(child.value, mode="eval"))
            except SyntaxError:
                pass
    return found


def is_loose_mapping(annotation: ast.AST) -> bool:
    """dict / Mapping / MutableMapping that is bare or whose values are Any or object."""
    node = annotation
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        try:
            node = ast.parse(node.value, mode="eval").body
        except SyntaxError:
            return False
    subscripted = {id(c.value) for c in ast.walk(node) if isinstance(c, ast.Subscript)}
    for child in ast.walk(node):
        if id(child) in subscripted:
            continue  # the `Mapping` in `Mapping[str, str]`; judged with its subscript
        base = child.value if isinstance(child, ast.Subscript) else child
        name = base.id if isinstance(base, ast.Name) else base.attr if isinstance(base, ast.Attribute) else None
        if name not in {"dict", "Dict", "Mapping", "MutableMapping"}:
            continue
        if not isinstance(child, ast.Subscript):
            return True
        args = child.slice.elts if isinstance(child.slice, ast.Tuple) else [child.slice]
        if len(args) == 2 and names_in(args[1]) & {"Any", "object"}:
            return True
    return False


class Scopes(ast.NodeVisitor):
    """Walks a module keeping the qualified name of the enclosing function."""

    def __init__(self, os_names: set[str]) -> None:
        # Names bound by `from os import environ, getenv`: only then is a bare
        # `environ` the process environment rather than a parameter.
        self.os_names = os_names
        self.stack: list[ast.AST] = []
        self.facts: dict[str, list[dict[str, object]]] = {
            "any_annotations": [],
            "loose_mapping_params": [],
            "float_uses": [],
            "priority_sets": [],
            "validate_calls": [],
            "env_reads": [],
            "calls": [],
            "newtypes": [],
            "validated_annotations": [],
            "functions": [],
        }
        self.enum_classes: list[dict[str, object]] = []
        self.model_fields: list[dict[str, object]] = []

    # -- scope bookkeeping ------------------------------------------------
    def qualname(self) -> str | None:
        parts = [n.name for n in self.stack if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))]
        if not any(isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) for n in self.stack):
            return None
        return ".".join(parts)

    def function(self) -> ast.FunctionDef | ast.AsyncFunctionDef | None:
        for node in reversed(self.stack):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                return node
        return None

    def add(self, key: str, node: ast.AST, **extra: object) -> None:
        self.facts[key].append({"line": getattr(node, "lineno", 0), "function": self.qualname(), **extra})

    def generic_visit(self, node: ast.AST) -> None:
        self.stack.append(node)
        super().generic_visit(node)
        self.stack.pop()

    # -- annotations ------------------------------------------------------
    def annotation(self, node: ast.AST | None, where: ast.AST) -> None:
        if node is None:
            return
        found = names_in(node)
        if "Any" in found:
            self.add("any_annotations", where, text=text(node))
        if "float" in found:
            self.add("float_uses", where, text=text(node))
        for child in ast.walk(node):
            if isinstance(child, ast.Subscript) and names_in(child.value) & {"Annotated"}:
                markers = names_in(child.slice)
                patterned = any(
                    isinstance(call, ast.Call) and any(k.arg == "pattern" for k in call.keywords)
                    for call in ast.walk(child.slice)
                )
                if markers & VALIDATOR_MARKERS or patterned:
                    self.add("validated_annotations", where, names=sorted(markers))

    def visit_FunctionDef(self, node: ast.FunctionDef | ast.AsyncFunctionDef) -> None:
        decorators = [text(d) for d in node.decorator_list]
        self.stack.append(node)
        self.facts["functions"].append({
            "line": node.lineno,
            "name": node.name,
            "qualname": self.qualname(),
            "nested": sum(isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) for n in self.stack) > 1,
            "returns": text(node.returns) if node.returns else None,
            "decorators": decorators,
            "raises": any(isinstance(n, ast.Raise) for n in ast.walk(node)),
            "branches": any(isinstance(n, (ast.If, ast.Match, ast.Assert)) for n in ast.walk(node)),
        })
        self.stack.pop()
        args = [*node.args.posonlyargs, *node.args.args, *node.args.kwonlyargs]
        if node.args.vararg:
            args.append(node.args.vararg)
        if node.args.kwarg:
            args.append(node.args.kwarg)
        for arg in args:
            self.annotation(arg.annotation, arg)
            if arg.annotation is not None and is_loose_mapping(arg.annotation):
                self.stack.append(node)
                self.add("loose_mapping_params", arg, param=arg.arg, text=text(arg.annotation))
                self.stack.pop()
        self.annotation(node.returns, node)
        self.generic_visit(node)

    visit_AsyncFunctionDef = visit_FunctionDef

    def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
        self.annotation(node.annotation, node)
        owner = self.stack[-1] if self.stack else None
        if isinstance(owner, ast.ClassDef) and isinstance(node.target, ast.Name):
            patterned = isinstance(node.value, ast.Call) and any(k.arg == "pattern" for k in node.value.keywords)
            self.model_fields.append({
                "class": owner.name,
                "field": node.target.id,
                "types": sorted(names_in(node.annotation)),
                "patterned": patterned,
            })
        self.generic_visit(node)

    def visit_TypeAlias(self, node: ast.TypeAlias) -> None:
        self.annotation(node.value, node)
        self.generic_visit(node)

    # -- value sets ---------------------------------------------------------
    def priority_strings(self, nodes: list[ast.expr]) -> set[str]:
        return {n.value for n in nodes if isinstance(n, ast.Constant) and n.value in PRIORITY_MEMBERS}

    def visit_Subscript(self, node: ast.Subscript) -> None:
        if names_in(node.value) & {"Literal"}:
            elts = node.slice.elts if isinstance(node.slice, ast.Tuple) else [node.slice]
            if len(self.priority_strings(list(elts))) >= 2:
                self.add("priority_sets", node, text=text(node))
        self.generic_visit(node)

    def collection(self, node: ast.List | ast.Tuple | ast.Set) -> None:
        owner = self.stack[-1] if self.stack else None
        inside_literal = isinstance(owner, ast.Subscript) and names_in(owner.value) & {"Literal"}
        if not inside_literal and len(self.priority_strings(list(node.elts))) >= 2:
            self.add("priority_sets", node, text=text(node))
        self.generic_visit(node)

    visit_List = visit_Tuple = visit_Set = collection

    def visit_Dict(self, node: ast.Dict) -> None:
        keys = [k for k in node.keys if k is not None]
        if len(self.priority_strings(keys)) >= 2:
            self.add("priority_sets", node, text=text(node)[:120])
        self.generic_visit(node)

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        bases = {b for base in node.bases for b in names_in(base)}
        if bases & {"Enum", "StrEnum"}:
            values = {
                stmt.value.value
                for stmt in node.body
                if isinstance(stmt, ast.Assign) and isinstance(stmt.value, ast.Constant)
            }
            if len(values & PRIORITY_MEMBERS) >= 2:
                self.enum_classes.append({"line": node.lineno, "name": node.name})
        validators = [
            {"decorator": text(d), "fields": [a.value for a in d.args if isinstance(a, ast.Constant)]}
            for stmt in node.body
            if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef))
            for d in stmt.decorator_list
            if isinstance(d, ast.Call) and "validator" in text(d.func)
        ]
        self.facts.setdefault("field_validators", []).extend(
            {"class": node.name, **v} for v in validators
        )
        self.generic_visit(node)

    # -- calls, environment, NewType ------------------------------------------
    def visit_Call(self, node: ast.Call) -> None:
        func = node.func
        name = func.id if isinstance(func, ast.Name) else func.attr if isinstance(func, ast.Attribute) else None
        if name:
            # Whether the enclosing function can reject its input: a NewType
            # conferred here is conferred by a validating constructor.
            fn = self.function()
            self.add(
                "calls",
                node,
                name=name,
                raises=fn is not None and any(isinstance(n, ast.Raise) for n in ast.walk(fn)),
                validator=fn is not None and any("validator" in text(d) for d in fn.decorator_list),
            )
        if name in VALIDATE_METHODS:
            self.add("validate_calls", node, method=name)
        if name == "float":
            self.add("float_uses", node, text=text(node))
        if name == "Decimal" and node.args:
            first = node.args[0]
            if isinstance(first, ast.Constant) and isinstance(first.value, float):
                self.add("float_uses", node, text=text(node))
        if text(func) == "os.getenv" or (isinstance(func, ast.Name) and func.id in self.os_names and func.id == "getenv"):
            self.add("env_reads", node, text=text(node))
        if name == "NewType":
            target = self.stack[-1] if self.stack else None
            if isinstance(target, ast.Assign) and isinstance(target.targets[0], ast.Name):
                self.facts["newtypes"].append({"line": node.lineno, "name": target.targets[0].id})
        self.generic_visit(node)

    def visit_Attribute(self, node: ast.Attribute) -> None:
        if text(node) == "os.environ":
            self.add("env_reads", node, text="os.environ")
        self.generic_visit(node)

    def visit_Name(self, node: ast.Name) -> None:
        if node.id == "environ" and "environ" in self.os_names:
            self.add("env_reads", node, text="environ")
        self.generic_visit(node)


def bare_ignores(source: str) -> list[dict[str, object]]:
    found: list[dict[str, object]] = []
    for token in tokenize.generate_tokens(io.StringIO(source).readline):
        if token.type != tokenize.COMMENT:
            continue
        comment = token.string
        for marker in ("type: ignore", "pyright: ignore"):
            at = comment.find(marker)
            if at != -1 and not comment[at + len(marker):].startswith("["):
                found.append({"line": token.start[0], "text": comment})
    return found


def casts(source: str, tree: ast.Module) -> list[dict[str, object]]:
    lines = source.splitlines()
    out: list[dict[str, object]] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and (
            (isinstance(node.func, ast.Name) and node.func.id == "cast")
            or (isinstance(node.func, ast.Attribute) and node.func.attr == "cast")
        ):
            here = lines[node.lineno - 1]
            above = lines[node.lineno - 2] if node.lineno > 1 else ""
            explained = "#" in here or above.strip().startswith("#")
            out.append({"line": node.lineno, "explained": explained})
    return out


def probe(path: Path) -> dict[str, object]:
    source = path.read_text(encoding="utf-8")
    try:
        tree = ast.parse(source, filename=str(path))
    except SyntaxError as err:
        return {"syntax_error": f"{err.msg} at line {err.lineno}"}
    os_names = {
        alias.name
        for n in ast.walk(tree)
        if isinstance(n, ast.ImportFrom) and n.module == "os"
        for alias in n.names
        if alias.asname is None
    }
    scopes = Scopes(os_names)
    scopes.visit(tree)
    facts: dict[str, object] = dict(scopes.facts)
    facts["enum_classes"] = scopes.enum_classes
    facts["model_fields"] = scopes.model_fields
    facts["bare_ignores"] = bare_ignores(source)
    facts["casts"] = casts(source, tree)
    facts.setdefault("field_validators", [])
    facts["imports_pydantic"] = any(
        (isinstance(n, ast.ImportFrom) and (n.module or "").startswith("pydantic"))
        or (isinstance(n, ast.Import) and any(a.name.startswith("pydantic") for a in n.names))
        for n in ast.walk(tree)
    )
    return facts


def main(argv: list[str]) -> int:
    json.dump({arg: probe(Path(arg)) for arg in argv}, sys.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

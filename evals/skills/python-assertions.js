// Deterministic graders for the python quality suite.
//
// The fixture declares strictly typed Python (README.md, CLAUDE.md, strict
// basedpyright, pydantic as a dependency) but shows none of the practice the
// cases grade: no model reads a request body, nothing reads the environment,
// ids are plain `str`, and nothing writes a file. The agent's code is found by
// content: a .py file under src/ that the trail edited or whose text differs
// from the committed fixture. Fixture code the agent never changed is not
// graded. Every rule below is one the python skill states; the comment quotes
// it.
//
// Structure comes from Python's own parser: python-probe.py runs under the
// workspace's interpreter and reports facts as JSON. The quality-lib runners
// (vitest, tsc) do not apply here, so this module has its own, all through
// `uv run`, which is how the fixture's README says the project runs its tools.

const lib = require("./quality-lib");
const { existsSync, readdirSync, statSync, writeFileSync, unlinkSync } = require("node:fs");
const { join, relative } = require("node:path");

const FIXTURE = lib.resolve(__dirname, "fixtures/python-workspace");
const PROBE = lib.resolve(__dirname, "python-probe.py");
const SKIP_DIRS = new Set([".venv", ".uv-cache", "__pycache__", ".pytest_cache", ".ruff_cache", ".git", ".claude", "node_modules"]);
const PRIORITY_OWNER = "src/ticket_desk/tickets.py";

const posix = (path) => path.split("\\").join("/");
const rel = (file) => posix(relative(lib.workspace(), file));

const pyFiles = (dir) => {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).flatMap((entry) => {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) return SKIP_DIRS.has(entry) ? [] : pyFiles(full);
    return entry.endsWith(".py") ? [full] : [];
  });
};

const productionFiles = () => pyFiles(lib.resolve(lib.workspace(), "src"));

// Changed = edited per the trail, new, or different from the fixture. The
// trail match compares workspace-relative tails so /private/var vs /var and
// Windows separators do not matter.
const changedFiles = (context) => {
  const edited = lib.edits(lib.trail(context)).map((call) => posix(call.path));
  return productionFiles().filter((file) => {
    const tail = rel(file);
    const original = lib.resolve(FIXTURE, tail);
    return edited.some((path) => path.endsWith(`/${tail}`)) || !existsSync(original) || lib.read(original) !== lib.read(file);
  });
};

const list = (files) => files.map(rel).join(", ") || "(none)";

const uv = (args, options) => lib.run(`uv run --quiet ${args}`, options);

// Facts for every given file, keyed by workspace-relative path.
const probe = (files) => {
  if (files.length === 0) return {};
  const quoted = files.map((file) => JSON.stringify(rel(file))).join(" ");
  const result = uv(`python -I ${JSON.stringify(PROBE)} ${quoted}`);
  if (!result.ok) throw new Error(`python-probe.py failed: ${result.out.slice(0, 400)}`);
  const json = result.out.slice(result.out.indexOf("{"));
  return Object.fromEntries(Object.entries(JSON.parse(json)).map(([path, facts]) => [posix(path), facts]));
};

const each = (facts, key) =>
  Object.entries(facts).flatMap(([path, fileFacts]) => (fileFacts[key] ?? []).map((fact) => ({ path, ...fact })));
const at = (fact) => `${fact.path}:${fact.line}`;

const requireWork = (context, grade) => {
  const files = changedFiles(context);
  if (files.length === 0) return lib.verdict(false, "the agent changed no production file under src/");
  const facts = probe(files);
  const broken = Object.entries(facts).filter(([, f]) => f.syntax_error);
  if (broken.length > 0) return lib.verdict(false, broken.map(([path, f]) => `${path}: ${f.syntax_error}`).join("; "));
  return grade(files, facts);
};

// --- shared rules -----------------------------------------------------------

// Core rule 2: "Annotate every function signature ... No bare `Any`, no
// unexplained `cast`, no blanket `# type: ignore`"; "Suppressions name the
// rule and the reason"; "Where a cast is unavoidable, comment why."
exports.noAny = (output, context) =>
  requireWork(context, (files, facts) => {
    const problems = [
      ...each(facts, "any_annotations").map((f) => `${at(f)} annotation uses Any: ${f.text}`),
      ...each(facts, "casts").filter((f) => !f.explained).map((f) => `${at(f)} cast without a comment saying why`),
      ...each(facts, "bare_ignores").map((f) => `${at(f)} suppression names no rule: ${f.text}`),
    ];
    return lib.verdict(problems.length === 0, problems.length === 0 ? `no Any, unexplained cast or bare ignore in ${list(files)}` : problems.join("; "));
  });

// "Errors" and "I/O, Time and Resources": "Always pass `encoding="utf-8"`";
// "Use `pathlib.Path`, not string paths and `os.path`"; "Datetimes are
// timezone-aware ... never `datetime.utcnow()` ... or a bare
// `datetime.now()`"; "No bare `except:`, no `except Exception: pass`";
// "Never use a mutable default"; "no `shell=True` with interpolated input.
// No `eval`/`exec`, no `pickle.load` or `yaml.load` on untrusted data".
// The fixture's own ruff config does not select these rules, so the
// project's lint run cannot teach them; this grader runs ruff with exactly
// these rules on the files the agent changed.
const SKILL_RULES = ["DTZ", "PLW1514", "PTH", "BLE", "S110", "S112", "B006", "B008", "S307", "S301", "S506", "S602", "S604"];
exports.ioTimeAndErrorRules = (output, context) =>
  requireWork(context, (files) => {
    const targets = files.map((file) => JSON.stringify(rel(file))).join(" ");
    const result = uv(`ruff check --isolated --preview --target-version py312 --output-format concise --select ${SKILL_RULES.join(",")} ${targets}`);
    const findings = result.out.split("\n").filter((line) => /:\d+:\d+: /.test(line));
    return lib.verdict(result.ok, result.ok ? `utf-8 I/O, pathlib, aware datetimes and narrow excepts in ${list(files)}` : findings.map(posix).join("; ") || result.out.slice(0, 300));
  });

// "When you change code, run the project's formatter, linter, type checker
// and tests before calling the work done. A type checker you did not run
// proves nothing." and "Do not install packages into the global interpreter
// or with `pip install` inside a uv or Poetry project". Each tool must run
// after the agent's last edit to a .py file.
const TOOLS = [
  { label: "type checker", pattern: /\b(basedpyright|pyright|mypy)\b/ },
  { label: "linter", pattern: /\bruff\s+check\b/ },
  { label: "tests", pattern: /\bpytest\b/ },
];
exports.toolsRun = (output, context) => {
  const calls = lib.trail(context);
  const lastEdit = Math.max(-1, ...lib.edits(calls).filter((call) => call.path.endsWith(".py")).map((call) => call.index));
  const commands = calls.filter((call) => call.name === "Bash");
  const installs = commands.filter((call) => /\bpip3?\s+install\b/.test(call.command));
  const after = commands.filter((call) => call.index > lastEdit);
  const missing = TOOLS.filter(({ pattern }) => !after.some((call) => pattern.test(call.command))).map(({ label }) => label);
  const problems = [
    ...missing.map((label) => `the ${label} did not run after the last edit`),
    ...installs.map((call) => `installed with pip instead of the project's tool: ${call.command.slice(0, 80)}`),
  ];
  return lib.verdict(problems.length === 0, problems.length === 0 ? "type checker, linter and tests all ran after the last edit; no pip install" : problems.join("; "));
};

// --- case rules -------------------------------------------------------------

// Core rule 3 and "Trust Boundaries": "HTTP bodies ... become a validated
// model before any other code touches them. Internal code takes those
// models, never `dict[str, Any]`"; "Use the validation library the project
// already has" (the fixture depends on pydantic).
exports.parsedAtBoundary = (output, context) =>
  requireWork(context, (files, facts) => {
    const validations = each(facts, "validate_calls");
    const loose = each(facts, "loose_mapping_params").map((f) => `${at(f)} parameter ${f.param}: ${f.text} carries unparsed data inward`);
    const problems = [
      ...(validations.length === 0 ? [`no pydantic validation (model_validate_json, model_validate, TypeAdapter.validate_*) in ${list(files)}`] : []),
      ...loose,
    ];
    return lib.verdict(problems.length === 0, problems.length === 0 ? `body parsed with ${validations.map((f) => `${f.method} at ${at(f)}`).join(", ")}; no loose mapping parameter` : problems.join("; "));
  });

// Core rule 4 and "One Owner per Value Set": "Before writing a
// `Literal[...]`, an enum, or an `in ("a", "b")` check, search for an
// existing declaration and derive from it"; "every type, validator, CLI
// choice list and database check derives from that declaration". The
// fixture already owns the priorities as `Priority(StrEnum)` in tickets.py.
exports.onePriorityOwner = (output, context) =>
  requireWork(context, (files, facts) => {
    const spellings = [
      ...each(facts, "priority_sets").map((f) => `${at(f)} spells the priorities again: ${f.text}`),
      ...each(facts, "enum_classes")
        .filter((f) => !(f.path === PRIORITY_OWNER && f.name === "Priority"))
        .map((f) => `${at(f)} declares a second priority enum ${f.name}`),
    ];
    return lib.verdict(spellings.length === 0, spellings.length === 0 ? "the priorities have one owner, Priority in tickets.py" : spellings.join("; "));
  });

// "Configuration is a boundary: load environment variables once at startup
// into a typed settings object ... and pass it in. Do not call `os.environ`
// from business logic." and "avoid ... work done at import time (... reading
// the environment)". What is graded is *when* the environment is read: only
// while the composition root (build_app or main) runs. A read may sit in the
// root itself or in a top-level helper that only the root calls (the first
// baseline's agents split the parsing of one variable into such a helper,
// which is still a single read at startup). A helper returns a named type,
// never a mapping. Reads in a handler, a nested function, a helper called
// from anywhere else, or at import time fail.
const ROOTS = new Set(["build_app", "main"]);
exports.configLoadedOnce = (output, context) =>
  requireWork(context, () => {
    const all = probe(productionFiles());
    const reads = each(all, "env_reads");
    if (reads.length === 0) return lib.verdict(false, "nothing under src/ reads the environment");
    const problems = reads.filter((f) => f.function === null).map((f) => `${at(f)} reads the environment at import time`);
    const owners = [...new Set(reads.filter((f) => f.function !== null).map((f) => `${f.path}::${f.function}`))];
    for (const owner of owners) {
      const [path, qualname] = owner.split("::");
      const fn = (all[path].functions ?? []).find((f) => f.qualname === qualname);
      const name = qualname.split(".").at(-1);
      if (fn?.nested) {
        problems.push(`${path}:${fn.line} ${qualname} reads the environment inside another function, so it runs per call, not once at startup`);
        continue;
      }
      if (ROOTS.has(name)) continue;
      if (!fn?.returns || /^(dict|Mapping|Any|object)\b/.test(fn.returns)) problems.push(`${path}:${fn?.line} ${qualname} returns ${fn?.returns ?? "nothing declared"}, not a typed value or settings object`);
      const callers = each(all, "calls").filter((c) => c.name === name);
      const strays = callers.filter((c) => !(c.function && ROOTS.has(c.function.split(".").at(-1))));
      if (callers.length === 0) problems.push(`${qualname} reads the environment but is never called`);
      problems.push(...strays.map((c) => `${at(c)} calls ${name}, which reads the environment, outside the composition root (in ${c.function ?? "module scope"})`));
    }
    return lib.verdict(problems.length === 0, problems.length === 0 ? `the environment is read only at startup, in ${owners.map((o) => o.split("::")[1]).join(" and ")}` : problems.join("; "));
  });

// "Distinct Types for Interchangeable Primitives": "When two values share an
// underlying type and could be swapped without the checker noticing (a user
// ID and an order ID ...), give each a `NewType` and confer it only in a
// validating constructor". Conferral counts as validated when the call sits
// in a function that can raise or is a pydantic validator, or when pydantic
// confers it through a field with a pattern or a validator.
const ID_KINDS = { Ticket: /ticket/i, Customer: /customer/i };
exports.distinctIds = (output, context) =>
  requireWork(context, () => {
    const all = probe(productionFiles());
    const newtypes = each(all, "newtypes");
    const problems = [];
    const found = Object.entries(ID_KINDS).map(([kind, pattern]) => {
      const declaration = newtypes.find((n) => pattern.test(n.name) && /id$/i.test(n.name));
      if (!declaration) problems.push(`no NewType for ${kind.toLowerCase()} ids`);
      return declaration;
    }).filter(Boolean);
    for (const { name } of found) {
      const calls = each(all, "calls").filter((c) => c.name === name);
      const unvalidated = calls.filter((c) => !c.raises && !c.validator);
      problems.push(...unvalidated.map((c) => `${at(c)} confers ${name} in ${c.function ?? "module scope"}, which validates nothing`));
      if (calls.length === 0) {
        const fields = each(all, "model_fields").filter((f) => f.types.includes(name));
        const validated = fields.some((f) => f.patterned || each(all, "field_validators").some((v) => v.class === f.class && (v.fields.length === 0 || v.fields.includes(f.field))));
        const annotated = each(all, "validated_annotations").length > 0 && fields.length > 0;
        if (!validated && !annotated) problems.push(`nothing validates a ${name} before conferring it (no constructor that raises, no field pattern or validator)`);
      }
    }
    return lib.verdict(problems.length === 0, problems.length === 0 ? `${found.map((n) => n.name).join(" and ")} are NewTypes, each conferred only after validation` : problems.join("; "));
  });

// "Money is never `float`. Use integer minor units or `Decimal` constructed
// from a string (`Decimal("19.99")`, not `Decimal(19.99)`)".
exports.moneyNotFloat = (output, context) =>
  requireWork(context, (files, facts) => {
    const uses = each(facts, "float_uses").map((f) => `${at(f)} ${f.text}`);
    return lib.verdict(uses.length === 0, uses.length === 0 ? `no float in ${list(files)}` : `float in money code: ${uses.join("; ")}`);
  });

// --- runners ----------------------------------------------------------------

const pytestSummary = (out) => (out.match(/^=*\s*\d+ (passed|failed|error).*$/m) ?? [out.split("\n").filter(Boolean).slice(-2).join(" | ")])[0].replace(/=+/g, "").trim();

// Copy a hidden test into tests/ (a name pytest collects), run only it, remove it.
exports.behaviourDelivered = (output, context) => {
  const name = context?.vars?.acceptance;
  const source = lib.resolve(__dirname, "tests", "python", "acceptance", name);
  const target = lib.resolve(lib.workspace(), "tests", `test_zz_acceptance_${name}`);
  writeFileSync(target, lib.read(source));
  try {
    const result = uv(`pytest -q -p no:cacheprovider ${JSON.stringify(rel(target))}`);
    return lib.verdict(result.ok, pytestSummary(result.out));
  } finally {
    if (existsSync(target)) unlinkSync(target);
  }
};

exports.suiteGreen = () => {
  const result = uv("pytest -q -p no:cacheprovider --ignore-glob=*acceptance*");
  return lib.verdict(result.ok, pytestSummary(result.out));
};

// Core rule 2: "keep it clean in strict mode". The fixture's checker is
// basedpyright in strict mode over src/ and tests/.
exports.typecheckClean = () => {
  const result = uv("basedpyright");
  const summary = (result.out.match(/\d+ errors?, \d+ warnings?.*$/m) ?? [result.out.split("\n")[0]])[0];
  return lib.verdict(result.ok, result.ok ? `basedpyright strict: ${summary}` : posix(summary + " | " + result.out.split("\n").find((line) => /error:/.test(line))?.trim()));
};

// Core rule 1: run "the project's own formatter, linter ...". The project's
// ruff config, as committed.
exports.lintClean = () => {
  const check = uv("ruff check --output-format concise");
  const format = uv("ruff format --check");
  const problems = [
    ...(check.ok ? [] : [`ruff check: ${posix(check.out.split("\n").filter(Boolean).slice(0, 3).join("; "))}`]),
    ...(format.ok ? [] : [`ruff format --check: ${posix(format.out.split("\n").filter(Boolean).slice(0, 2).join("; "))}`]),
  ];
  return lib.verdict(problems.length === 0, problems.length === 0 ? "ruff check and ruff format --check clean" : problems.join("; "));
};

module.exports = lib.withWorkspace(module.exports);

# Skill routing

Which skill to load for which kind of work. Every name without "when
installed" is a craft skill and is always available (`craft:<name>` in Claude
Code). A name followed by "when installed" comes from another plugin or skill
collection; skip it if it is not there. CI fails if a line names a craft skill
that sits on the shelf, so promote a skill before routing to it.

## Process and workflow

For detailed TDD workflow, load the `tdd` skill.
For detailed testing patterns and examples, load the `testing` skill.
For refactoring methodology, load the `refactoring` skill.
For removing total branches, states, dependencies, layers, flags, retries, jobs, or operational moving parts from a selected existing path while conserving behavior, load the `reduce-system-complexity` skill. Pure reductions use the verified REFACTOR path, not a fabricated structural RED test.
For reviewing whether a test suite's design actually pins behavior, load the `test-design-reviewer` skill.
For verifying test effectiveness through mutation analysis, load the `mutation-testing` skill at the end-of-phase PR-readiness gate.
For CI failure diagnosis, load the `ci-debugging` skill.
For local or runtime failure diagnosis — an error message, permission denial, crash, or wrong output outside CI — load `debugging` to preserve evidence, localize one causal hypothesis at a time, and fix the earliest shared owning boundary when a fix is requested.
For a read-only decision on whether finished implementation satisfies an authoritative requirement, load `acceptance-review` and report every criterion plus its evidence and exact verdict.
For reviewing a branch, pull request or work in progress against the repository's written standards and against its spec, load `review` (two separate axes; the harness's own reviewer covers bugs).
For a rigorous second opinion on finished work, load `double-check`. It selects an available reviewer dynamically, prefers a different provider when possible, labels a same-provider fresh-context fallback honestly, and bounds unresolved disagreement rather than requiring artificial consensus.
When the user is unsure which skill or flow fits, point them at `/ask` (the `ask` skill); it maps every craft skill, including shelved ones.
At the end of a session, especially one that went sideways, suggest `/retro` (the `retro` skill) to turn what went wrong into changes to the environment.
For delegating a labelled GitHub issue end to end, or watching and landing delegated pull requests, use `/delegate` (the `delegating-github-issues` skill).

## Discovery, specification and planning

For fuzzy product/design decisions, load `grilling` to pressure-test the decision tree in rounds before writing stories or plans. The user can start it themselves with `/grill-with-docs` (records terms and decisions in the repository) or `/grill-me` (writes nothing).
For turning fuzzy intent into shared understanding and acceptance criteria — agent-facilitated draft followed by accountable, risk-proportionate human review — load the `specification` skill.
For naming domain concepts, glossary work, or any new/changed domain term — the five-step language protocol, never silent coinage — load the `ubiquitous-language` skill.
For broad stories, epics, features, or backlog items, load `story-splitting` to create child stories before planning.
For tightening an existing story, plan, acceptance criteria set, or mock spec, load `find-gaps` to write confirmed answers back into the artifact.
For significant implementation work, load `planning` to turn one selected child story or narrow capability into the repository's declared planning workflow and location; use `plans/` only as the documented fallback.
When one planned vertical slice may be too large for review, or later slices should start on the same evolving baseline before lower PRs merge, load `stack-pull-requests` with `planning` to choose independent PRs or an explicit hard-/flow-lineage stack without turning technical layers into stories or slices.
For multi-surface design audits before code (embed every mock in a scope on one reviewable page with flow diagram + gap cards + per-mock audit checklists), load the `storyboard` skill.

## Architecture and services

For API and interface design patterns, load the `api-design` skill.
For OAuth 2.0 or OpenID Connect design, implementation, review, testing, incident analysis, or migration, load the `secure-oauth-oidc` skill.
For hexagonal architecture projects, load the `hexagonal-architecture` skill.
For Domain-Driven Design projects, load the `domain-driven-design` skill.
For event-sourced systems or bounded contexts (events as the source of truth, the Decider write model, event stores, projections and read models, event versioning, snapshots), load the `event-sourcing` skill.
For 12-factor service projects, load the `twelve-factor` skill; before a service's first production deploy, or when it works in one environment and not another, run the `twelve-factor-audit` agent.
For production observability (wide events, OpenTelemetry, SLOs/alerting, telemetry testing), load the `observability` skill.
For browser-facing BFF or backend HTTP entry points — public/protected access classification, authentication middleware, session cookies, CSRF/Origin policy, protected SSE/WebSocket registration, and endpoint-protection enforcement — load the `bff-entry-points` skill.
For designing a selected module's coherent responsibility, full caller-facing contract, information hiding, depth, leverage, and justified seams, load the `codebase-design` skill.
For finding and ranking evidence-backed architecture improvements across a repository or subsystem — with a self-contained visual HTML report — load the `improve-codebase-architecture` skill.
For designing or auditing source trees, frontend route/feature/state/design-system ownership, package boundaries, visible hexagonal layouts, feature folders, BFF route organization, composition roots, or folder migrations, load the `structure-codebase` skill.
Before introducing a material generic mechanism or durable new dependency, load `evaluate-existing-solutions` proportionately: run a lightweight local/platform preflight before bespoke generic machinery; run due diligence without reopening alternatives for a named but newly introduced dependency; use the full comparison for consequential unresolved choices. Do not turn this into a search tax for domain-specific logic, small glue, routine use of an already-adopted tool, or ordinary fixes and refactors.

## Legacy code

For making untestable code testable, load the `finding-seams` skill.
For documenting existing behavior before changes, load the `characterisation-tests` skill.

## Front end and UI

For browser or UI test strategy, load the `front-end-testing` skill; for React component testing, load the `react-testing` skill.
For front-end flow logic, load the `xstate` skill — and load it *before* reaching for `useState`, not only when a file already imports xstate. Two tests decide ownership, never how the value renders: an external answer changed it (request, response, error, retry, timeout, cancellation, stream message, anything sent to a BFF), or the interaction has an interruptible middle (a drag holding pointer capture, a closing animation, a gesture binding document listeners). A disabled button or spinner is the presentation *of* temporal state. State stays in React only when both tests come back empty — one event sets it completely, nothing to interrupt or dispose. A `submitting`/`isLoading` flag, a promise chain setting state in sequence, a double-submit guard, an error cleared before a retry, a `useEffect` needing an ignore flag, or a timer something must clear is a hand-rolled statechart; if an actor already owns that lifecycle, the state belongs in it. Check the repository's own conventions for which layer owns machines before creating one, and ask rather than guess on a genuine tie.
For React or Next.js performance work, load the `react-performance` skill: baseline the symptom, attribute the cost with evidence, apply one rule at a time from the pinned `vercel-react-best-practices` catalogue, then re-measure. Behavior tests stay unchanged and green; immutability and typing rules are not traded for speed, and unmeasured optimizations are reverted rather than kept.
For walking a changed UI in a real browser against the project's doctrine checklist, load the `browser-ux-walkthrough` skill.
For frontend interface design, redesign, critique, polish, visual hierarchy, motion, theming, or design-system extraction, load `impeccable` when installed; for general frontend design within an existing design system, load `frontend-design` when installed.
For React composition and component API design, load `vercel-composition-patterns` when installed; for view transitions and route/element animation in React, load `vercel-react-view-transitions` when installed.
For a full performance/accessibility/SEO/best-practice sweep of a site, load `web-quality-audit` when installed; for search visibility or technical SEO, load `seo-audit` when installed.

## Writing, knowledge and skills

For developer-facing prose — READMEs, guides, tutorials, reference docs, proposals, release notes — load the `technical-writing` skill (reader-first structure, falsifiable claims, agent-readable reference shape).
For reader-facing prose that needs sentence-level co-writing, rewriting, review, or diagnostics because it feels generic, hollow, or AI-shaped, load `clarity` when installed. `technical-writing` owns the document's reader job, structure, and verifiable claims; `clarity` owns substance, voice, and sentences.
For technical prose requested in plain English, layman's terms, ASD-STE100, or a form suitable for non-native readers or translation, load `simple-english` when installed. Use its Plain mode by default and its Strict mode only when the user names STE or compliance; leave marketing and brand voice to `clarity`.
For diagrams and visual documentation, load the `diagrams` skill.
For deciding where a learning, gotcha or decision should live, load the `expectations` skill.
For documents an *agent* consumes rather than a human — a SKILL.md, `CLAUDE.md`/`AGENTS.md`, or a doc reached by a pointer — load `writing-for-agents`: context pointers and trigger wording, the context/cognitive load split, the information hierarchy and progressive disclosure, and completion criteria that resist premature completion. Route by audience, not by file type: `technical-writing` owns human-facing prose, `writing-for-agents` owns agent-facing instruction.
For authoring, restructuring, evaluating, or benchmarking a skill itself — drafting from scratch, running evals over test prompts, or tuning a description for trigger accuracy — load `skill-creator` when installed. Use `writing-for-agents` for how the words should read and `skill-creator` for the authoring and measurement loop around them.
For grading installed skills against recent local agent conversations, load `skill-doctor` when installed. It owns retrospective scoring and evidence-backed improvement proposals; use `skill-creator` for authoring and controlled prompt evals.
For discovering and installing agent skills from the open ecosystem (`npx skills`), load the `find-skills` skill.
For learning a topic over several sessions, the user can run `/teach`, which keeps a teaching workspace in the current directory.
When the previous answer did not land, use `/wtf` to have it re-explained in plain, precise UK English.

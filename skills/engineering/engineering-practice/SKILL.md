---
name: engineering-practice
description: Core engineering practice for any coding task — TDD is non-negotiable for behaviour change, behaviour-driven testing, TypeScript strict, immutable data and pure logic, small increments with the mutation gate at PR readiness — plus the routing table that says which craft skill to load for which kind of work. Load this first in any coding task, before planning or editing code.
---

# Engineering practice

These are the working guidelines for every coding task. Your global
`CLAUDE.md` / `AGENTS.md` points here, and a plugin install carries no other
copy, so this skill is the single source of truth. Repository-specific
`CLAUDE.md` / `AGENTS.md` files override it where they disagree.

**Which skill for which work:** read [`references/routing.md`](references/routing.md)
when the task goes beyond the quick references below, and follow it rather than
guessing.

## Core philosophy

**TEST-DRIVEN DEVELOPMENT IS NON-NEGOTIABLE FOR NEW OR CHANGED BEHAVIOR.** Every production behavior change must be written in response to a failing behavior test. Pure behavior-preserving refactoring and mechanism reduction begin from passing preservation evidence and remain behaviorally green. Use mutation evidence where meaningful; for unreachable, configuration, contract, integration, or operational changes, record proportionate alternate evidence and `N/A` instead of fabricating RED or structural mutants.

Follow Test-Driven Development with a strong emphasis on behavior-driven
testing and functional programming principles. Do all work in small,
incremental changes that keep a working state throughout development.

For mutation-testing cadence, a **phase of work** means one PR review boundary. Normally that is one PR-sized, independently mergeable slice; in a cross-slice stack it is one whole-slice member, and in an intra-slice stack it is one focused dependent layer. It does not mean a multi-PR feature/stack as a whole or a numbered lifecycle phase in a project plan.

## Quick reference

**Key principles:**

- Write behavior tests first for new or changed behavior (TDD)
- Test behavior, not implementation
- No unexplained `any`; contain unavoidable interop and justify assertions
- Prefer immutable values and pure logic; isolate necessary mutation and effects
- Cohesive functions behind stable module contracts
- TypeScript strict mode always
- Reuse an existing production schema when it adds test evidence; do not
  redefine the same contract

**Preferred tools:**

- **Language**: TypeScript (strict mode)
- **Testing**: Follow the repository harness; prefer real-browser evidence
  when the claim depends on browser behaviour and the cost is justified
- **State management**: Prefer immutable patterns

## Testing

**Core principle**: Test behavior, not implementation. Cover changed and
high-risk behavior proportionately; a coverage percentage is not proof.

- Write behavior tests first for new or changed behavior (TDD non-negotiable)
- Test through the subject's public interface at the layer the claim names (an HTTP endpoint is the wrong interface for a browser claim)
- Use factories for repeated or nested test data; isolated lifecycle hooks and
  clear one-off values are valid
- Tests must document expected business behavior
- Organize tests around behavior and repository ownership, not a universal
  file-count rule

For detailed testing patterns and examples, load the `testing` skill.
For verifying test effectiveness through mutation analysis, load the `mutation-testing` skill at the end-of-phase PR-readiness gate; use its mutator rules earlier for cheap test-design guidance without running the automated harness.

## TypeScript

**Core principle**: Strict mode always. Schema-first at trust boundaries, types for internal logic.

- No unexplained `any`; use `unknown` at untrusted boundaries and contain
  unavoidable interop
- No type assertions without justification
- Follow repository convention for `type`/`interface`, then language semantics
- Define schemas at runtime trust boundaries and derive types from them
- Use plain types, smart constructors, or domain values for trusted internal logic

For detailed TypeScript patterns and rationale, load the `typescript-strict` skill.

## Code style

**Core principle**: Prefer immutable data and pure logic where they make
behavior easier to reason about; keep necessary effects explicit.

- Prefer immutable values; contain mutation where a boundary, library, or
  measured performance need requires it
- Pure functions wherever possible
- Use early returns or composition when they make branching clearer
- Use comments for non-obvious why, constraints, and safety context
- Use an options object when positional parameters are ambiguous or unstable
- Choose array methods or loops by clarity, control flow, and measured needs
- Compose small private functions behind cohesive, stable module contracts; do not equate one helper with one public module

For detailed patterns and examples, load the `functional` skill.

## Development workflow

**Core principle**: Use fast RED-GREEN-REFACTOR increments for changed behavior. Run mutation testing or review alternate evidence once at the end-of-phase PR-readiness gate, after implementation and refactoring are complete.

- RED: Write a failing behavior test before new or changed behavior
- GREEN: Write MINIMUM code to pass test
- REFACTOR OR REDUCE: Assess applicable improvements while ordinary behavior tests stay green
- REPEAT: Continue the inner cycle without running the automated mutation harness after each increment, refactor, or commit
- PRE-PR MUTATION GATE: When the phase is otherwise ready for a PR, run mutation testing once for the accumulated scope where meaningful; otherwise record `N/A` plus proportionate reachability, configuration, contract, integration, or operational evidence
- KILL MUTANTS: During that gate, address valuable survivors and re-run focused/diff mutation checks as part of the same gate (ask the human when value is ambiguous)
- Each increment leaves codebase in working state

For a behavior-changing planned slice, load `tdd`, `testing`, and applicable refactoring guidance before code changes begin. Use the `mutation-testing` skill's mutator rules for cheap test-design guidance, but do not run its harness until the end-of-phase PR-readiness gate. For a pure behavior-preserving refactor/reduction, load only the applicable testing, refactoring, and reduction skills during implementation, then apply mutation testing or alternate evidence at the same PR gate; load `reduce-system-complexity` when net mechanism removal is claimed, and record why any other skill is `N/A`. Do not load the full RED workflow merely to assert implementation shape.

For the PR-readiness evidence gate before creating a PR (change-path classification and mutation-evidence freshness), read the `mutation-testing` skill's `references/pr-readiness.md`.

**Project-level hooks:** When the repository supports hooks and the user authorizes project configuration, consider a PostToolUse typecheck/format hook using the repository's existing toolchain.

## Output guardrails

- **Honor the requested artifact boundary** — Persist a plan or document only
  when the user asks for a file or the repository declares that durable owner.
  Otherwise answer in chat without creating a new source of truth.
- **Plan-only mode** — When asked for a plan, design, or document only, produce ONLY that artifact. Do not write production code, test code, or make any implementation changes unless explicitly asked.
- **Incremental output** — When exploring a codebase, produce a first draft of output within 3-4 tool calls. Refine iteratively rather than front-loading all exploration before producing anything.

## Working practice

**Core principle**: Think deeply, follow TDD strictly, capture learnings while context is fresh.

- ALWAYS FOLLOW TDD for behavior change; keep pure refactors/reductions behaviorally green from passing, proportionate preservation evidence
- Assess refactoring after every green (but only if adds value)
- Ask "What do I wish I'd known at the start?" after significant changes
- Route durable, non-obvious learnings through `expectations` to their actual
  owner: source/tests, glossary, accepted decision mechanism, maintained docs,
  active plan, or repository working policy
- Update a repository's `CLAUDE.md` / `AGENTS.md` only for local working policy
  it is declared to own, and only when the request or repository workflow
  authorizes that write

## Browser automation

Prefer `agent-browser` for web automation when it is installed; otherwise use
the browser or fetch tools the harness provides.

1. `agent-browser open <url>` - Navigate to page
2. `agent-browser snapshot -i` - Get interactive elements with refs (@e1, @e2)
3. `agent-browser click @e1` / `fill @e2 "text"` - Interact using refs
4. Re-snapshot after page changes

## Summary

Write clean, testable, functional code that evolves through small, safe increments. Drive production-behavior changes with a test that describes the desired behavior; use claim-appropriate evidence for documentation, configuration, dependency, generated, CI, and operational changes. The implementation should be the simplest thing that makes the test or other governing check pass. When in doubt, favor simplicity and readability over cleverness.

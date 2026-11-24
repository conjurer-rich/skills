# expectations: source notes

## Records That Cannot Track the Code

The section's discipline (date every claim, cite the commit a code claim was
true at, supersede rather than rewrite) comes from the "Write history, not
the present" rules in Matt Pocock's in-progress `chief-of-staff` skill:

- Repository: <https://github.com/mattpocock/skills>
- Revision: [`5beb35b0`](https://github.com/mattpocock/skills/blob/5beb35b040e3de97e54fa9e386d7e42d15c295c2/skills/in-progress/chief-of-staff/SKILL.md)
  (MIT)

Upstream applies it to one wiki that holds a long-running session's memory.
craft does not adopt the wiki: this skill routes each learning to the
document that owns it. The rules apply only to destinations that cannot
change with the code.

Licence status: ideas only, no text copied. The wording is original to this
repository.

## Say How Often It Was Seen

The provenance tag, `(seen N×: …)` or `(seen 1×, unverified)`, comes from the
mined correlation tables in Anthropic's oncall-kit plugin. There, every
lesson mined from past incidents carries its count and incident ids, and a
single-sighting row is a hypothesis, not a conclusion:

- Repository: <https://github.com/anthropics/oncall-kit> (fork:
  <https://github.com/conjurer-rich/oncall-kit>)
- Revision: [`c03282cd`](https://github.com/anthropics/oncall-kit/blob/c03282cd5381a5a2e12e32bfb3c8957d52ce01f1/skills/oncall-setup/SKILL.md)
  (Apache-2.0), `skills/oncall-setup/SKILL.md` and
  `skills/triage/references/test-failures.md`

craft applies the tag to any learning recorded from experience. It also uses
the count as the evidence bar for promoting a local learning to a global
skill.

Licence status: ideas only, no text copied. The tag's form is a convention,
and the wording is original to this repository.

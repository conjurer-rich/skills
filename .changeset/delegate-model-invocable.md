---
"@conjurer-rich/skills": patch
---

delegate: drop `disable-model-invocation`, so `/loop /craft:delegate` works again. `/loop` runs its prompt through the Skill tool, which the flag refused, though the skill's own description opens with "Keep delegating under /loop". Codex still never invokes it implicitly: `agents/openai.yaml` keeps `allow_implicit_invocation: false`, as every claude-only skill must.

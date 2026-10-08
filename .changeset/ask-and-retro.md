---
"@conjurer-rich/skills": minor
---

Two new user-invoked skills, adapted from Matt Pocock's `ask-matt` and `retro` (MIT, `mattpocock/skills@b0618bc4`):

- `/craft:ask` maps every craft skill, agent and command into flows (idea to ship, plus on-ramps for bugs, legacy code, upkeep and deploys) and lists shelved skills with when to promote them. CI now fails if a shipped item is missing from it; it is the only shipped file allowed to name a shelved item.
- `/craft:retro` reviews a session and proposes changes to the environment: navigation pointers, automated checks, coding standards, steering files, tooling, information access, and a new **missed skills** category that compares the session against `craft:ask`'s map.

---
"@conjurer-rich/skills": minor
---

`delegating-github-issues`: the implementer's model now follows the tier Work predicts from the issue before handoff. A predicted tier S (clearly one package, no `risk_paths`; any doubt is not S) runs on `sonnet`; anything else runs on `opus` as before. A Sonnet implementer that returns `blocked`, or whose diff measures not S, is re-dispatched once on `opus` in the same worktree, briefed with the first attempt's outcome; it never steps down. Projects can change the models with the new `implementer_model_small` (default `sonnet`) and `implementer_model_large` (default `opus`) parameters. Land's reviewer and Sync's resolution check stay on `opus`.

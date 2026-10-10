---
"@conjurer-rich/skills": patch
---

`delegating-github-issues`: an unanswered **Question before delegation** now keeps an issue `waiting-on-human` even when it has acceptance criteria in its body or confirmed derived criteria, so Pick no longer offers an issue whose question the delegator is still waiting on. A bot comment after the question no longer counts as the human's answer. The human answers by replying; editing the issue body is not an answer.

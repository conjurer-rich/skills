---
"@conjurer-rich/skills": patch
---

`delegate-fire`'s reusable workflow failed on its first GitHub call: `delegate-status` asked `gh api user` for the delegator's login, and a GitHub Actions token is no user. `delegate-status` now takes the login from `DELEGATE_STATUS_LOGIN` when set, and says to set it when `gh api user` fails. The reusable workflow sets it from a new `delegator-login` input, which defaults to the calling repository's owner.

---
"@conjurer-rich/skills": patch
---

`delegate-fire` now uses the reserve token only for reservations: taking lease slots and setting tickets. The gate's reads stay on the workflow token. Previously the reusable workflow ran every call with the reserve token, so a token scoped to Issues failed with HTTP 403 when listing pull requests. The reserve token also needs **Pull requests: read-only**, because setting a ticket reads the open PRs, and the setup guide now says so.

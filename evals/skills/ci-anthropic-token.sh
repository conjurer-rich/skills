#!/usr/bin/env bash
#
# Print a short-lived Anthropic access token for a GitHub Actions job, by
# workload identity federation. Claude Code runs this as its `apiKeyHelper`
# (see .github/workflows/skill-evals.yml).
#
# Every call fetches a NEW GitHub OIDC token before it exchanges it. Anthropic
# accepts an identity token once (`jti_reused` otherwise), and the suites start
# many Claude Code processes, so they cannot share one token.
#
# Needs: ACTIONS_ID_TOKEN_REQUEST_URL and ACTIONS_ID_TOKEN_REQUEST_TOKEN (the
# job has `id-token: write`), and WIF_FEDERATION_RULE_ID, WIF_ORGANIZATION_ID,
# WIF_SERVICE_ACCOUNT_ID, WIF_WORKSPACE_ID.

set -euo pipefail

jwt="$(curl -sSf -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=https://api.anthropic.com" | jq -er .value)"

body="$(jq -nc \
  --arg assertion "$jwt" \
  --arg rule "$WIF_FEDERATION_RULE_ID" \
  --arg org "$WIF_ORGANIZATION_ID" \
  --arg account "$WIF_SERVICE_ACCOUNT_ID" \
  --arg workspace "$WIF_WORKSPACE_ID" \
  '{grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: $assertion,
    federation_rule_id: $rule, organization_id: $org,
    service_account_id: $account, workspace_id: $workspace}')"

response="$(curl -sS https://api.anthropic.com/v1/oauth/token \
  -H "content-type: application/json" --data "$body")"

if ! token="$(jq -er .access_token <<<"$response")"; then
  # An error body holds no token, so it is safe to show.
  echo "Anthropic token exchange failed: $response" >&2
  exit 1
fi
printf '%s\n' "$token"

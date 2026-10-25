# IntuneGet-Build

Builds HRM's IntuneGet container image: upstream
[ugurkocde/IntuneGet](https://github.com/ugurkocde/IntuneGet) at a release tag,
plus the small patches in `patches/`. Published to HRM's private Azure Container Registry as
`intuneget:<tag>-hrm.<rev>` (the registry address is the repo variable `ACR_LOGIN_SERVER`).

Build settings mirror upstream's release workflow (pinned actions, provenance, SBOM).

## Patches

| Patch | Why | Drop when |
|---|---|---|
| `0001-qa-gate-skip-without-supabase.patch` | In SQLite (no Supabase) mode the QA gate calls Supabase unconditionally, so GitHub-mode packaging can't start. From v0.8.2 the gate also checks installer reputation (VirusTotal) in Supabase, so this patch skips that check too in SQLite mode. | Upstream guards `enforceQaGate` for self-hosted installs. |
| `0002-tenant-view-without-supabase.patch` | Deployments → "All in tenant" (`GET /api/package?scope=tenant`) calls Supabase unconditionally, so the team view fails in SQLite mode. | Upstream guards the tenant-scope branch. |
| `0003-webhooks-without-supabase.patch` | Settings → Notifications webhooks return 503 in SQLite mode, and `/api/cron/send-notifications` needs Supabase. Stores webhooks in SQLite (migration 9, `webhook_configurations`, created with `IF NOT EXISTS` so tables made by earlier builds are kept) and delivers them from the cron; email still needs Supabase. The VM runs `/api/cron/send-notifications` after each `/api/cron/check-updates`. | Upstream supports webhooks in SQLite mode. |
| `0004-app-mappings-winget-ids.patch` | Seven built-in app mappings point to WinGet IDs that don't exist (for example `Webex.Webex`; the real ID is `Cisco.Webex`), so Claim fails with "Failed to fetch package manifest". Fixes them and adds a live check (`VALIDATE_WINGET_IDS=1`) that every mapped ID resolves; products not in WinGet are listed in the test. | Upstream fixes the IDs and validates them. |
| `0005-reports-count-deployed-jobs.patch` | Reports counts only `completed` jobs as successful, but GitHub-mode packaging finishes jobs as `deployed`, so Successful, the success rate and the charts stay at zero. Counts both, as the dashboard statistics already do. | Upstream counts `deployed` in `/api/analytics`. |
| `0006-deployment-webhooks.patch` | Self-hosted IntuneGet sends webhooks only for available updates; deployment results go out only in hosted MSP mode. When a packaging job finishes as deployed or failed, posts one message to every enabled webhook on the server (Teams Adaptive Card, Slack, Discord, or JSON with `deployment.completed` / `deployment.failed`). SQLite mode has no tenant table, so this assumes one Intune tenant per server. | Upstream sends deployment results to webhooks in SQLite mode. |
| `0007-webhook-managed-identity.patch` | Teams Workflows' V2 webhook trigger refuses unsigned requests. With `WEBHOOK_MANAGED_IDENTITY=true`, webhooks to Power Platform hosts (`*.environment.api.powerplatform.com`, `*.logic.azure.com`) carry a token for the server's Azure managed identity, so the flow can allow only the server. The token is never sent to other hosts. | Upstream supports signed webhooks to Teams Workflows. |

## Branding

`branding/hrm-mark.svg` (House of Ruth Maryland mark, from hruth.org) replaces the IntuneGet
logo: the build writes it to `public/favicon.svg` (sidebar logo + tab icon) and renders the
PNG/ICO icon sizes from it.

## How a release reaches the server

1. Every Monday, "Check for a new upstream release" applies the patches to the newest upstream
   release, runs upstream's type check and tests, and opens a "Build upstream vX" PR that moves
   `upstream-ref`. If a patch no longer applies, it opens an issue instead.
2. Merging that PR builds the image (`<tag>-hrm.<n>`, next free `n`) and opens a "Deploy" PR
   that moves `deploy/version`.
3. Merging the Deploy PR deploys. Every 5 minutes the VM compares `deploy/version` with what it
   runs; on a change it backs up its data, switches the image, waits for it to report healthy,
   and restores the backup and the old image if it doesn't.

To roll back, revert the Deploy PR. Details, the VM setup and the rules for changing patches
are in [CLAUDE.md](CLAUDE.md).

To rebuild by hand: Actions → "Build patched IntuneGet image" → Run workflow.

## Retire

When upstream fixes the issue, switch the server back to `ghcr.io/ugurkocde/intuneget:<tag>`
and archive this repo.

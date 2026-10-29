# IntuneGet-Build

Builds HRM's IntuneGet container image: upstream
[ugurkocde/IntuneGet](https://github.com/ugurkocde/IntuneGet) at a release tag,
plus the small patches in `patches/`. Published to HRM's private Azure Container Registry as
`intuneget:<tag>-hrm.<rev>` (the registry address is the repo variable `ACR_LOGIN_SERVER`).

Build settings mirror upstream's release workflow (pinned actions, provenance, SBOM).

## Patches

| Patch | Why | Drop when |
|---|---|---|
| `0001-qa-gate-skip-without-supabase.patch` | In SQLite (no Supabase) mode the QA gate calls Supabase unconditionally, so GitHub-mode packaging can't start. Skips only the Supabase checks (installation test history, compatibility blocks and the VirusTotal reputation store); the catalog snapshot's verdict still applies: a malicious VirusTotal result blocks even with an override, a failed test blocks unless overridden. | Upstream guards `enforceQaGate` for self-hosted installs. |
| `0002-tenant-view-without-supabase.patch` | Deployments → "All in tenant" (`GET /api/package?scope=tenant`) calls Supabase unconditionally, so the team view fails in SQLite mode. | Upstream guards the tenant-scope branch. |
| `0003-webhooks-without-supabase.patch` | Settings → Notifications webhooks return 503 in SQLite mode, and `/api/cron/send-notifications` needs Supabase. Stores webhooks in SQLite (migration 9, `webhook_configurations`, created with `IF NOT EXISTS` so tables made by earlier builds are kept) and delivers them from the cron; email still needs Supabase. The VM runs `/api/cron/send-notifications` after each `/api/cron/check-updates`. | Upstream supports webhooks in SQLite mode. |
| `0004-app-mappings-winget-ids.patch` | Seven built-in app mappings point to WinGet IDs that don't exist (for example `Webex.Webex`; the real ID is `Cisco.Webex`), so Claim fails with "Failed to fetch package manifest". Fixes them and adds a live check (`VALIDATE_WINGET_IDS=1`) that every mapped ID resolves; products not in WinGet are listed in the test. | Upstream fixes the IDs and validates them. |
| `0005-reports-count-deployed-jobs.patch` | Reports counts only `completed` jobs as successful, but GitHub-mode packaging finishes jobs as `deployed`, so Successful, the success rate and the charts stay at zero. Counts both, as the dashboard statistics already do. | Upstream counts `deployed` in `/api/analytics`. |
| `0006-deployment-webhooks.patch` | Self-hosted IntuneGet sends webhooks only for available updates; deployment results go out only in hosted MSP mode. When a packaging job finishes as deployed or failed, posts one message to every enabled webhook on the server (Teams Adaptive Card, Slack, Discord, or JSON with `deployment.completed` / `deployment.failed`). SQLite mode has no tenant table, so this assumes one Intune tenant per server. | Upstream sends deployment results to webhooks in SQLite mode. |
| `0007-webhook-managed-identity.patch` | Teams Workflows' V2 webhook trigger refuses unsigned requests. Webhooks to the exact flow URLs in `WEBHOOK_MANAGED_IDENTITY_URLS` carry a token for the server's Azure managed identity (scheme, host, port and path must match), and those requests refuse redirects. Any tenant can own a Power Automate or Logic Apps URL, so no other URL is ever signed. | Upstream supports signed webhooks to Teams Workflows. |
| `0008-security-dependency-updates.patch` | Upstream v0.8.2 ships Next.js 16.4.0, affected by critical advisories (GHSA-2464-fhr4-w9xw, GHSA-673q-mjm6-r5xr) and a denial of service (GHSA-p3m5-59mp-jv5r). Updates Next.js and eslint-config-next to 16.4.3, zod to 4.6.7, sharp to 0.35.5, @azure/msal-node to 7.1.1 and baseline-browser-mapping to 2.11. Left as is: the msal-node 6 copy inside @azure/identity (only its managed-identity credential is used) and fflate 0.6 inside three-stdlib. | Upstream releases v0.8.3 or later with these versions. |
| `0009-discovered-apps-catalog-matching.patch` | Discovered Apps matches only against ~90 built-in mappings and suggests by letter similarity ("UniFi Endpoint" → McAfee). Matches the rest against the full catalog by name words (full-text, name column only); automatic only for an identical name, an agreeing publisher and a clear winner, otherwise up to 3 suggestions; skips ARM-only packages for non-ARM apps; drops suggestions that share no meaningful word; labels Microsoft Store apps and hides their Link Package button. | Upstream matches discovered apps against its catalog. |
| `0010-hrm-home-help-branding.patch` | The server shows upstream's public marketing site, which has no audience behind Cloudflare Access. Sends the home page and marketing pages to the dashboard and blocks crawlers; replaces the dashboard with HRM's Home (needs attention, recent deployments across HRM, server status, shortcuts); adds an HRM Help page; hides SCCM, MSP and app-request menu items; HRM wording on the sign-in page; HRM purple and teal in place of the cyan and violet accents. Server status reads `hrm-status.json`, written by `deploy/intuneget-status.sh`. | Never; HRM-specific. |
| `0011-curated-catalog-runtime-refresh.patch` | The curated catalog is a signed list built into the image that expires 7 days after upstream signs it, so the Curated Catalog page fails a week after each release. Also reads a newer signed list from the data folder (`curated-catalog.json`, downloaded daily by `deploy/intuneget-curated-refresh.sh`) and serves whichever list verifies against the image's built-in keys and was signed most recently; a forged, expired or unreadable download is ignored. | Upstream serves the curated catalog to self-hosted installs without an image rebuild. |
| `0012-sqlite-updates-and-auto-update.patch` | On a SQLite server Update / Update All return 503 (Supabase only), auto-update jobs wait for a local packager that GitHub-mode servers don't have, and their history never completes. Adds the SQLite path for Update / Update All (upstream's SQLite trigger and safety checks, then the GitHub packaging run with the installation-test gate), dispatches scheduled auto-update jobs the same way, records completion and the failure circuit breaker through the database adapter, and shows App Updates in the menu. Updates supersede the previous version and carry over its groups. | Upstream supports updates and auto-update on SQLite with GitHub packaging. |
| `0013-update-deployed-by.patch` | Update jobs come from upstream's auto-update code, which stores no email, so the Teams card said "Deployed by: Unknown". Records the signed-in person on Update / Update All jobs and shows "Auto-update" for scheduled ones. | Upstream records who triggered an update. |

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

# IntuneGet-Build: working rules

Builds HRM's IntuneGet image (upstream `ugurkocde/IntuneGet` plus the patches in `patches/`) and
tells HRM's IntuneGet VM which image to run. The server stores its data in SQLite
(`DATABASE_MODE=sqlite`); a move to Supabase is possible later, so keep deploy steps
database-agnostic.

**This repo is public.** No secrets, hostnames, IP addresses, resource names or client data in
any file, commit, issue or PR. Server details live in the private IntuneGet-Workflows repo and
HRM IT notes.

## Files

| Path | What it is |
|---|---|
| `upstream-ref` | Upstream release tag the build uses (for example `v0.8.2`) and, on the second line, the commit it pointed at when it was checked. The build fails if the tag has moved since. |
| `patches/*.patch` | HRM changes, applied in name order with `git apply`. Why each exists: README. |
| `deploy/version` | Image tag the server should run (for example `v0.8.2-hrm.1`) and, on the second line, the image digest the build recorded. The VM refuses the tag if it no longer points at that digest. **Changing it on `main` deploys to production.** |
| `deploy/intuneget-deploy.sh` | The VM's deploy script (installed as `/usr/local/sbin/intuneget-deploy`). |
| `deploy/systemd/` | VM timers: deploy check every 5 minutes, update check and notifications twice a day, scheduled update start hourly (patch 0030), optional startup Beta report collection hourly (patch 0044), Intune self-test daily at 7:15 AM New York (patch 0032). |
| `deploy/cloudflared-apt-update.sh` | Nightly cloudflared update through apt (installed as `/usr/local/sbin/cloudflared-apt-update`), run by the `cloudflared-update` drop-in in `deploy/systemd/cloudflared-update.service.d/`. |
| `deploy/intuneget-status.sh` | Writes `hrm-status.json` into the app's data volume every 5 minutes (installed as `/usr/local/sbin/intuneget-status`, run by `intuneget-status.timer`) for the Home page's Server status card. Its `checks` section holds verdicts the app, watchdog and IT dashboard report all read as-is: Intune reads (install results or app activity failed at the last 2 update checks), the daily Intune self-test, the hourly scheduled-update run, and whether sign-in is limited to the IT admins group (patch 0056), and Version sync after deploy (patch 0057, read from the app's cron-authenticated `/api/cron/version-sync-status`). |
| `deploy/intuneget-watchdog.py` | Every 5 minutes (installed as `/usr/local/sbin/intuneget-watchdog`, run by `intuneget-watchdog.timer`): checks the app's health and the status file and posts to IT Ops in Teams when a problem is confirmed, daily while it lasts, and when it clears. `intuneget-watchdog status` lists current problems; `intuneget-watchdog test` sends a test post. |
| `deploy/intuneget-curated-refresh.sh` | Daily at 2:15 AM New York (installed as `/usr/local/sbin/intuneget-curated-refresh`, run by `intuneget-curated-refresh.timer`): downloads upstream's latest signed curated catalog into the app's data volume for patch 0011. |
| `deploy/intuneget-backup.py` | Nightly at 1:30 AM New York (installed as `/usr/local/sbin/intuneget-backup`, run by `intuneget-backup.timer`): copies the SQLite database while the app runs, checks it, compresses it and uploads it to the Azure Storage container in `BACKUP_CONTAINER_URL` as the VM's managed identity. `intuneget-backup status` shows the last result. |
| `deploy/tests/` | Python tests for the status script's `checks.versionSync` field and the watchdog's alerts (stub commands, temporary files). `scripts/check-app.sh full` runs them. |
| `.github/workflows/upstream-check.yml` | Weekly: newer upstream release? Test the patches on it and open the "Build upstream" PR (or an issue). |
| `.github/workflows/build.yml` | On `main` changes to `upstream-ref`, patches or branding: check Help (below), build `<tag>-hrm.<n>` and open the "Deploy" PR. |
| `.github/workflows/tests.yml` | For code PR revisions: apply pinned patches, cache npm downloads, check Help and both app/packager types, then run the full regression suite once. Deploy-only PRs and description edits do not run the suite. Manual dispatch covers bot-created upgrade PRs. |
| `scripts/check-app.sh` | Shared local/PR validation entry point for a patched tree with dependencies installed. `related` runs affected tests during iteration; `full` checks Help, both compiler configurations and all tests. |
| `.github/workflows/help-check.yml` | On PRs that change patches, `upstream-ref` or `deploy/` (not `deploy/version`): run the Help check and require "Help and tooltips checked" ticked in the PR description. |
| `docs/mcp-api.md` | The MCP read API contract (patch 0055): endpoints, parameters, response fields with fake examples, and where the server differs from the MCP Worker's first contract. |
| `scripts/check-help.mjs` | The Help check: every on-screen label a Help section lists in `uiLabels` (patch 0034) still exists in the app, every time Help gives matches a timer in `deploy/systemd/`, and HRM's tooltips and hints keep the writing rules. Run by the build, the weekly upstream check and PRs. |
| `scripts/migration-numbers.mjs` | Finds SQLite migration numbers the way `lib/db/sqlite-migrations.ts` defines them (`version: N,` on its own line or inline), in upstream's file and in the lines the patches add to that file only. The weekly upstream check uses it to flag HRM migrations that upstream has reached; `scripts/check-app.sh full` runs its tests. |

## Registry and sign-in

- Images go to HRM's shared Azure Container Registry (Basic tier, private). Its address, and the IDs
  GitHub signs in with, are repo secrets: `ACR_LOGIN_SERVER`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`.
  None of them is truly secret, but run logs here are public and GitHub masks only secrets, so never
  move them back to variables. Keep registry and resource names out of files, logs and step output.
- **Build:** an Entra app with a federated credential for this repo's `main` branch (it uses GitHub's
  immutable subject, `repo:<org>@<org id>/<repo>@<repo id>:ref:refs/heads/main`) holds AcrPush on the
  registry only. No client secret exists.
- **VM:** its system-assigned managed identity holds AcrPull on the registry only. The deploy script
  swaps it for a short-lived registry token per pull and deletes it afterwards.
- Tokens are passed to `curl` and `docker` on stdin, never as command arguments, so they don't show
  in the process list. Keep it that way in new scripts and workflow steps.
- **Cleanup:** an ACR task runs every Sunday at 07:00 UTC and keeps the 5 newest tags of each app (plus
  removes untagged manifests). It goes by build date, not by what's deployed.
- Other HRM apps can use the same registry: give each repo its own app registration and federated
  credential with AcrPush, and each host AcrPull.

## Release flow

1. Weekly check opens **"Build upstream vX"**. Read the release notes and the checks table.
2. If the PR says the packaging workflow changed: update `.github/workflows/package-intunewin.yml`
   in IntuneGet-Workflows to the vX version (from upstream's `.github/workflows-reference/`) in its
   own PR. Merge it right before the Deploy PR, not earlier, because the running server still
   expects the old one.
3. Merge "Build upstream vX". The image builds and **"Deploy vX-hrm.N"** opens.
4. Merging the Deploy PR deploys to production. Only David approves this.
5. Within about 5 minutes the VM backs up, upgrades and checks health. Confirm on the VM:
   `sudo intuneget-deploy status` and `journalctl -u intuneget-deploy -n 50`.

## Changing or reworking a patch

- The working copy of the edits is a clone of upstream in `~/Developer/third-party/intuneget-deploy`.
  Make the change there, then regenerate the patch with `git diff <base> > patches/000N-....patch`.
  New files must be staged (`git add -N`) to appear in the diff.
- Check every patch applies, in order, to a clean checkout of the tag in `upstream-ref`, the same way
  the build does (`git apply`).
- Install dependencies once per lockfile change: `npm ci --no-audit --no-fund` and
  `(cd packager && npm ci --ignore-scripts --no-audit --no-fund)` in the patched tree.
- During implementation, use focused tests or `scripts/check-app.sh <patched tree> related <source files>`.
  Run `scripts/check-app.sh <patched tree> full` once after the final changes, and again only after
  new relevant changes, a failure or an unresolved concern. Full mode checks Help, app types,
  packager types with its own compiler, and all tests. Compare failures with upstream when needed.
- Keep the default process workers and per-file test isolation enabled. A thread-pool benchmark
  was faster but failed follow-up native-code validation; do not disable isolation or drop database,
  authorization, timeout or installer regressions for speed.
- Code PRs run the full suite in Patched app regression checks. Description edits do not rerun it;
  Deploy PRs reuse the tested code and built image. The build still checks Help against its exact
  app/timer inputs and compiles the production image. VM health and Windows installer QA are
  different checks and stay in place. Bot-created upgrade PRs may need a manual workflow dispatch
  because GitHub does not trigger another workflow from a PR opened with the Actions token.
- When a patch calls something new from a module that upstream tests mock with `vi.mock`, add it to
  that mock in the same patch.
- **Migration numbers:** patches that add SQLite migrations take the next number after upstream's
  highest. Use `IF NOT EXISTS` so a table created by an earlier build is kept. If upstream reaches the
  same number, renumber the HRM migration above upstream's highest before building. The weekly check flags this.
- **App mapping IDs:** patch 0004 checks that every built-in app mapping resolves in WinGet. Run it on a
  patched tree with `VALIDATE_WINGET_IDS=1 GITHUB_TOKEN=$(gh auth token) npx vitest run lib/__tests__/app-mappings-winget.test.ts`.
  Fix a failing ID only after confirming the replacement's package name matches the product; add products
  that WinGet doesn't distribute to `NOT_IN_WINGET` in that test.
- A patch change on `main` builds a new `hrm.N` and opens a Deploy PR.
- Update the patch table in README.md and add a CHANGELOG.md entry.

## Notifications

- Webhooks are set up in IntuneGet under Settings → Notifications (type Microsoft Teams, no secret).
- **Teams channel flow** (Power Automate): trigger "When a Teams webhook request is received (V2)",
  Who can trigger = **Specific users in my tenant**, Allowed users = the VM's managed identity object ID
  (`az vm identity show -g <rg> -n <vm> --query principalId -o tsv`). Then "Apply to each" over the
  trigger's Attachments, with "Post card in a chat or channel" (Flow bot, the channel, card
  `item()?['content']`). Unsigned or other callers get 401/403.
- Patch 0007 signs those posts: put the flow's exact HTTP URL in `WEBHOOK_MANAGED_IDENTITY_URLS` in
  `.env.local` (several URLs separated by commas) and pass it through `docker-compose.override.yml`
  (`- WEBHOOK_MANAGED_IDENTITY_URLS=${WEBHOOK_MANAGED_IDENTITY_URLS:-}`). Never widen this to a host or
  domain: anyone can own a Power Automate or Logic Apps URL, and a signed test message to their URL
  would hand them the server's token.
- The flow posts with its owner's Teams connection. Keep an IT admins security group as co-owner, and
  move the connection to a shared IT account if the owner changes.
- Update notifications (patch 0003) go to the webhook owner's webhooks after each update check.
- Deployment results (patch 0006) go to **every** enabled webhook on the server as soon as a job
  finishes as deployed or failed. That's correct only while the server serves one Intune tenant.
- Messages carry app names, versions, staff emails, links and error text only; never add device,
  user or client details to them.
- **Server alerts** also cover the server's own Intune reads (patch 0032): install results or app
  activity failing at 2 update checks in a row, the daily read-only Intune self-test
  (`/api/cron/intune-self-test`), and the hourly scheduled-update run. Graph changes without notice;
  when the self-test fails, compare the failing read with Microsoft's Graph changelog.
- **Version sync after deploy** (patch 0057): a server alert when App updates wasn't corrected
  after 2 or more deploys in 24 hours (patch 0049's step in the deploy callback). The app records
  each result with a fixed code, never error text; the next successful correction, or a 3:30 update
  check that rebuilt App updates, clears it.
- When auto-update turns itself off for an app after 3 failed updates in a row, every enabled webhook
  gets one "Auto-update turned off" message (installer-check blocks don't count).
- **Server alerts** come from two places. The VM watchdog (`intuneget-watchdog`) posts through the
  same signed flow (first URL in `WEBHOOK_MANAGED_IDENTITY_URLS`) when a problem is seen on two
  checks in a row, daily while it lasts, and when it clears; it is quiet during deploys. It can't
  report the VM itself being down, so a Cloudflare **Tunnel Health Alert** (Notifications, free on
  every plan) emails the IT Ops channel's email address when the tunnel goes degraded or down.

## Access to the app

Patch 0056 lets only HRM's IT admins Entra security group use IntuneGet, inside the app, behind
Cloudflare Access. Two settings on the VM, never in this repo:

- `HRM_ADMIN_GROUP_IDS`: the group's object ID (several separated by commas, at most 20).
- `HRM_TENANT_ID`: HRM's Entra tenant ID. It is the one tenant setting: the MCP read API reads it
  too. A server set up with `MCP_TENANT_ID` keeps working, since that is read when
  `HRM_TENANT_ID` is unset; move it to `HRM_TENANT_ID` when convenient.

With the group set, every staff API route (through `parseAccessToken`, and the request proxy for a
clear `403`) checks the token's tenant and asks Graph `POST /me/checkMemberGroups` with the user's
own sign-in token. User.Read covers it and nested groups count, so no new permission or consent is
needed. Each decision is kept in memory for 5 minutes per user, so adding or removing someone takes
up to 5 minutes. A failed check refuses (`503`, Try again) and is not kept. Refused staff see "You
don't have access to IntuneGet. Ask HRM Support (https://support.hruthmd.org) to add you to the IT
admins group." Cron, the status report, workflow callbacks, the packager, QA and the MCP read API
never go through this check.

Unset (or no well-formed group ID), nothing changes and Home's Server status shows "Not limited to
a group" under Who can sign in. The status file records it as `checks.appAccess`; the watchdog doesn't
post about it.

Setup, once the image with patch 0056 is deployed:

1. Find the group's object ID and the tenant ID (signed in to the Azure CLI as an admin):

   ```bash
   az ad group show --group "<IT admins group name>" --query id -o tsv
   az account show --query tenantId -o tsv
   ```
2. On the VM, add both to `.env.local` without echoing them into the shell history or logs:
   `sudoedit /opt/intuneget/.env.local` and add `HRM_ADMIN_GROUP_IDS=<group object ID>` and
   `HRM_TENANT_ID=<tenant ID>`. If `MCP_TENANT_ID` is already there with the same value, rename it
   to `HRM_TENANT_ID` (and in the override below) rather than keeping both.
3. Pass both through `docker-compose.override.yml`, then recreate `web` with `--env-file .env.local`:

   ```yaml
         - HRM_ADMIN_GROUP_IDS=${HRM_ADMIN_GROUP_IDS:-}
         - HRM_TENANT_ID=${HRM_TENANT_ID:-}
   ```

   ```bash
   cd /opt/intuneget && sudo docker compose --env-file .env.local up -d web
   ```
4. Sign in as a group member (the app loads) and check Home's Server status shows Who can sign
   in: IT admins group. If possible, try a test account outside the group and expect the No access page.

Keep Entra and Cloudflare Access matching the same group (recommended):

- Entra ID → Enterprise applications → IntuneGet's app → Properties: set **Assignment required**
  to Yes, and under Users and groups assign only the IT admins group. Others then can't get a
  sign-in token at all.
- Cloudflare Access: limit the IntuneGet application's Allow policy to the same group (an Entra
  group include rule; the Entra login method needs group support turned on), not the whole tenant. Leave the status report
  Bypass and the MCP Service Auth policy as they are.

To turn the limit off again, remove `HRM_ADMIN_GROUP_IDS` from `.env.local` and recreate `web`.

While it is unset, the IT dashboard report shows a "Limit IntuneGet sign-in to IT-Admins" to-do
(patch 0058); it goes once the group is set. The report's pill doesn't change.

## IT dashboard status report

Patch 0027 serves `GET /api/status-report` for HRM's IT dashboard (format: hrm-it-dashboard
`docs/status-report.md`). It is built in `lib/hrm/status-report.ts` from the status file and job and
deploy counts. Counts and states only: never add app names, staff names or emails, tenant IDs,
device names or error text to it. The report tests check independent synthetic forbidden markers, version-tag
allowlisting, UTC calendar buckets, text limits and the 64 KB limit. Server status follows Home; the
watchdog additionally checks app health and whether scheduled checks and alerts are late.

Setup, once the image with patch 0027 is deployed:

1. On the VM, add the key to `.env.local` without printing it, and pass it through
   `docker-compose.override.yml` (`- STATUS_REPORT_KEY=${STATUS_REPORT_KEY:-}`), then recreate `web`
   with `--env-file .env.local`:

   ```bash
   sudo sh -c 'umask 077; printf "\nSTATUS_REPORT_KEY=%s\n" "$(openssl rand -hex 32)" >> /opt/intuneget/.env.local'
   ```

   Missing, wrong or unset keys always receive an empty `401`; configured keys must have at least
   32 characters. Invalid credentials never consume the valid key's allowance.
2. In Cloudflare Access, add a Bypass application for this one path (`<host>/api/status-report`)
   so the dashboard's request isn't sent to sign-in. Nothing else on the server is bypassed.
3. On the IT dashboard's Connections page, enter `https://<host>/api/status-report` and the same key.
   Copy the key from the VM over SSH; never paste it into chat, issues or this repo.

Authenticated requests receive `200`, using a server-side cache rebuilt at most once a minute per
configured key. Concurrent requests share one build. A 2.25-second deadline returns the last safe
report, preserving its original `generatedAt`, or a fixed down report if no safe report exists.
Throws anywhere in the build return only the fixed down report, with no exception text. Key rotation
starts a fresh cache. Responses use `Cache-Control: no-store`; this cache is inside the server.

SQLite counts are aggregate queries in a cancellable worker with its own read-only connection and
200 ms busy timeout. They do not change the app connection or load app/staff/error records. Status
file reads are limited to 32 KB before parsing. Supabase mode retains the adapter's bounded history
reads under the same response deadline. The report's daily buckets use UTC calendar days.

Links in the report's to-dos use only the parsed https origin of `NEXT_PUBLIC_URL`; credentials,
paths, query strings and fragments are never copied. Invalid or credential-bearing URLs are omitted.
Only strict release tags can appear as version text. Output text/item limits and the UTF-8 report
size are enforced at a single boundary.

## MCP read API

Patch 0055 serves a read-only API under `/api/hrm/mcp/` for HRM's MCP server (the
`hrm-intuneget-mcp` Cloudflare Worker). The contract, every endpoint and its fields, is
`docs/mcp-api.md`; change it in the same PR as the patch, and tell whoever keeps the Worker. It is
built in `lib/hrm/mcp-api.ts` (answers) and `lib/hrm/mcp-auth.ts` (who may call it). Names, IDs,
versions, counts, group names and codes only: never add staff emails, user or tenant IDs, device
names, Intune descriptions, installer URLs or raw error, status or reason text. Install errors go
out as a normalized code and HRM's own category. GET only; it never writes.

Every request needs both a bearer key (`MCP_API_KEY`, same rules as `STATUS_REPORT_KEY`) and a
Cloudflare Access JWT for the Worker's service token. The server checks the JWT signature against
the team's keys, the issuer, the audience (`ACCESS_AUD`), the expiry and that `common_name` is the
service token's client ID (`MCP_ACCESS_CLIENT_ID`). `HRM_TENANT_ID` (or the older `MCP_TENANT_ID`)
names the one Intune tenant it reads. If any setting is missing or malformed, the API is off and answers an empty `401`. The
Worker's `X-HRM-Requested-By` email goes to the server log only.

Setup, once the image with patch 0055 is deployed:

1. Cloudflare Access already has a path-only Access application for `<host>/api/hrm/mcp` and
   `<host>/api/hrm/mcp/*` with a **Service Auth** policy for the Worker's service token only. Do
   **not** add a Bypass for these paths: unlike the status report, the API needs Access to put the
   service token's JWT on every request.
2. On the VM, add the settings to `.env.local` without printing them. Generate the key in place:

   ```bash
   sudo sh -c 'umask 077; printf "\nMCP_API_KEY=%s\n" "$(openssl rand -hex 32)" >> /opt/intuneget/.env.local'
   ```

   Then add `ACCESS_TEAM_DOMAIN` (`<team>.cloudflareaccess.com`), `ACCESS_AUD` (the Access
   application's audience tag), `MCP_ACCESS_CLIENT_ID` (the service token's client ID, not its
   secret) and, if it isn't there yet, `HRM_TENANT_ID` (the Intune tenant ID, shared with
   "Access to the app") with `sudoedit /opt/intuneget/.env.local`.
   None of these go in this repo.
3. Pass all five through `docker-compose.override.yml` (skip `HRM_TENANT_ID` if "Access to the app" already added it), then recreate `web` with `--env-file .env.local`:

   ```yaml
         - MCP_API_KEY=${MCP_API_KEY:-}
         - ACCESS_TEAM_DOMAIN=${ACCESS_TEAM_DOMAIN:-}
         - ACCESS_AUD=${ACCESS_AUD:-}
         - MCP_ACCESS_CLIENT_ID=${MCP_ACCESS_CLIENT_ID:-}
         - HRM_TENANT_ID=${HRM_TENANT_ID:-}
   ```

   ```bash
   cd /opt/intuneget && sudo docker compose --env-file .env.local up -d web
   ```
4. Put the same `MCP_API_KEY` in the Worker's secret store. Copy it from the VM over SSH; never
   paste it into chat, issues or this repo. To rotate it, replace the line in `.env.local`, recreate
   `web` and update the Worker's secret.

Check from the VM that it stays closed without credentials (expect `401`):
`curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/api/hrm/mcp/status`.
Requests through the tunnel without the service token never reach the server.

Answers are never cached outside the server (`Cache-Control: no-store`); the app list from Intune
is kept inside the server for one minute. Each request has a 6-second deadline and a 256 KB limit;
both answer an empty `503`.

## Old copies

Patch 0042 (with 0050's timing) removes older Intune copies of an app that IntuneGet deployed, at the
3:30 update check. Each old copy is removed once all of these hold:

- the next version replaced it 7 or more days ago (counted per old copy, so apps released more often
  than weekly still get cleaned),
- the newest copy has healthy installs (at least 1 successful install, failures 10% or less),
- the newest copy supersedes it (directly or through other copies of the app),
- the newest copy already has every one of its groups, with the same intent and filter,
- no pilot, retirement, going back or deployment of the app is under way.

The copy you would roll back to (the one the newest replaced) is always kept for its first 7 days.
It deletes from Intune, so keep these rules strict: never widen it to copies added by hand, removal
copies, or copies whose groups differ. To turn it off, add `HRM_OLD_COPY_CLEANUP=off` to `.env.local`, pass it
through `docker-compose.override.yml` (`- HRM_OLD_COPY_CLEANUP=${HRM_OLD_COPY_CLEANUP:-}`) and recreate
`web` with `--env-file .env.local`.

## Deploys and rollback

- Roll back by reverting the Deploy PR. Going to an older version restores the backup taken when the
  server last moved off that version, so anything changed since that upgrade is lost.
- The VM keeps the last 5 backups (`/opt/intuneget/backups`). If the backup for the target version was
  pruned, the script refuses and changes nothing; restore by hand (below) or from an Azure snapshot.
- A failed deploy rolls back and is not retried. After fixing the cause: `sudo intuneget-deploy retry`.
- If `deploy/version` names an image that isn't built yet, the VM waits and tries again.
- Always run compose on the VM with `--env-file .env.local`; that file holds the app's settings and
  secrets. Without it the app starts with blank settings.

Manual restore of a backup on the VM:

```bash
cd /opt/intuneget && sudo docker compose --env-file .env.local stop web
sudo rsync -a --delete /opt/intuneget/backups/<backup>/data/ /var/lib/docker/volumes/intuneget_intuneget-data/_data/
sudo cp /opt/intuneget/backups/<backup>/docker-compose.override.yml /opt/intuneget/
sudo docker compose --env-file .env.local up -d web
```

Then make `deploy/version` match the restored tag, or the next timer run will deploy again.

## Off-site database backups

- Every night at 1:30 AM New York the VM uploads a checked, compressed copy of the database to a
  private Azure Storage container in another region (cool tier, no public access, no shared keys).
  The VM's managed identity has Storage Blob Data Contributor on that container only. A lifecycle
  rule deletes copies after 31 days. Secrets (`.env.local`) are not in the backup.
- The container's address goes in `BACKUP_CONTAINER_URL` in `/etc/default/intuneget-deploy` (kept
  out of this repo). The status file records the last off-site backup, and the watchdog posts in
  Teams if it failed or is more than 36 hours old.

Restore from an off-site copy, with an Azure CLI signed in as someone with Storage Blob Data Reader
on the container:

```bash
az storage blob list --auth-mode login --account-name <account> -c <container> --prefix intuneget/YYYY/MM/ -o table
az storage blob download --auth-mode login --account-name <account> -c <container> -n <blob> -f intuneget.db.gz
gunzip intuneget.db.gz && python3 -c "import sqlite3; print(sqlite3.connect('intuneget.db').execute('PRAGMA integrity_check').fetchone()[0])"
```

Then copy it to the VM, stop the app, replace `intuneget.db` in the data volume (keep the old one
aside), and start it again, as in the manual restore above. Try a restore against a copy first,
never the live database.

## VM setup (one time, and when the script or timers change)

Updates to `deploy/intuneget-deploy.sh` or `deploy/systemd/` don't reach the VM by themselves.
Reinstall them deliberately, on the VM over SSH:

```bash
git clone --depth 1 https://github.com/House-of-Ruth-Maryland/IntuneGet-Build /tmp/igb && cd /tmp/igb
sudo install -m 0755 deploy/intuneget-deploy.sh /usr/local/sbin/intuneget-deploy
sudo install -m 0644 deploy/systemd/*.service deploy/systemd/*.timer /etc/systemd/system/
sudo install -m 0644 deploy/systemd/intuneget-deploy.default /etc/default/intuneget-deploy  # first time only; set IMAGE_REPO and APP_URL
sudo install -m 0755 deploy/cloudflared-apt-update.sh /usr/local/sbin/cloudflared-apt-update
sudo install -m 0755 deploy/intuneget-status.sh /usr/local/sbin/intuneget-status
sudo install -m 0755 deploy/intuneget-watchdog.py /usr/local/sbin/intuneget-watchdog
sudo install -m 0755 deploy/intuneget-curated-refresh.sh /usr/local/sbin/intuneget-curated-refresh
sudo install -m 0755 deploy/intuneget-backup.py /usr/local/sbin/intuneget-backup
sudo install -D -m 0644 deploy/systemd/cloudflared-update.service.d/apt.conf /etc/systemd/system/cloudflared-update.service.d/apt.conf
sudo systemctl daemon-reload
```

cloudflared comes from Cloudflare's apt repository. The `cloudflared-update` timer that
`cloudflared service install` creates runs `cloudflared update` at midnight UTC, which refuses to
update an apt install, so the drop-in points that timer at `cloudflared-apt-update` instead. It
updates only the cloudflared package, restarts the tunnel only when the version changed (the site is
unreachable for a few seconds) and fails if the tunnel isn't back within two minutes. To update by
hand and see the result:

```bash
sudo systemctl start cloudflared-update.service && journalctl -u cloudflared-update.service -n 5 --no-pager
```

First time only, generate the cron secret on the VM. It goes into `.env.local` for the app and into a
root-only header file for the timers, and is never printed:

```bash
sudo sh -c 'umask 077; s=$(openssl rand -hex 32); printf "\nCRON_SECRET=%s\n" "$s" >> /opt/intuneget/.env.local; install -d -m 0700 /etc/intuneget; printf "Authorization: Bearer %s\n" "$s" > /etc/intuneget/cron-auth.header'
```

Check, then enable:

```bash
sudo intuneget-deploy run && sudo intuneget-deploy status
sudo intuneget-backup && sudo intuneget-backup status
sudo systemctl enable --now intuneget-deploy.timer intuneget-check-updates.timer intuneget-send-notifications.timer intuneget-status.timer intuneget-watchdog.timer intuneget-curated-refresh.timer intuneget-backup.timer intuneget-start-updates.timer intuneget-intune-self-test.timer cloudflared-update.timer
```

The app's port is published only on the VM itself (`127.0.0.1:3000:3000` in
`/opt/intuneget/docker-compose.yml`); the tunnel reaches it at `http://localhost:3000`.

Install the deploy script before merging the first Deploy PR whose `deploy/version` has a digest
line: older copies of the script can't read the two-line file and stop deploying until updated.

## How we work

- Ask before every push to `main`, and say what it triggers: patch, `upstream-ref` or branding changes
  start a build; `deploy/version` changes deploy to production.
- Never merge a Deploy PR or change `deploy/version` without David saying so in that conversation.
- Third-party services stay in test mode; secrets only in GitHub secrets or root-only files on the VM.
- Update CHANGELOG.md for every change to what the server runs or how it deploys.
- **Help and tooltips stay true to every build.** Run the `help-writer` agent
  (`.claude/agents/help-writer.md`) before committing any change to a patch, a deploy script or a VM
  timer, and on every "Build upstream" PR (against upstream's changes). When the app's logic changes,
  it rewrites the task guides, their visual focus labels, grouped reference rules, and the
  tooltips and hints that describe it. Keep primary workflows short; preserve existing guide IDs
  and related links. Details belong in named collapsed groups, not new unstructured paragraphs. Fold its edits into the patch that changes the behaviour (or a Help-only patch), run
  `node scripts/check-help.mjs <patched tree> .`, and tick `- [x] Help and tooltips checked: <what
  changed>` in the PR description. The PR check and the build fail without them.
- **Help is always updated by the `help-writer` agent, never by hand.** Don't edit
  `lib/hrm/help-content.ts`, `lib/hrm/help-guides.ts`, Help illustrations, tooltips or hints directly;
  give the change to `help-writer` and fold in what it writes. This applies to every session,
  subagent and Orca worker: any task spec that changes a patch, a deploy script or a timer must tell
  the worker to run `help-writer` and report what Help text it changed.

## Retire

When upstream fixes what the patches cover, run upstream's image (`ghcr.io/ugurkocde/intuneget:<tag>`):
point `IMAGE_REPO` in `/etc/default/intuneget-deploy` and the override at it, then archive this repo.

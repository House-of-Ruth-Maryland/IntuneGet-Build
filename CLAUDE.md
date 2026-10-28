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
| `upstream-ref` | Upstream release tag the build uses (for example `v0.8.2`). |
| `patches/*.patch` | HRM changes, applied in name order with `git apply`. Why each exists: README. |
| `deploy/version` | Image tag the server should run (for example `v0.8.2-hrm.1`). **Changing it on `main` deploys to production.** |
| `deploy/intuneget-deploy.sh` | The VM's deploy script (installed as `/usr/local/sbin/intuneget-deploy`). |
| `deploy/systemd/` | VM timers: deploy check every 5 minutes, update check and notifications twice a day. |
| `deploy/cloudflared-apt-update.sh` | Nightly cloudflared update through apt (installed as `/usr/local/sbin/cloudflared-apt-update`), run by the `cloudflared-update` drop-in in `deploy/systemd/cloudflared-update.service.d/`. |
| `deploy/intuneget-status.sh` | Writes `hrm-status.json` into the app's data volume every 5 minutes (installed as `/usr/local/sbin/intuneget-status`, run by `intuneget-status.timer`) for the Home page's Server status card. |
| `deploy/intuneget-watchdog.py` | Every 5 minutes (installed as `/usr/local/sbin/intuneget-watchdog`, run by `intuneget-watchdog.timer`): checks the app's health and the status file and posts to IT Ops in Teams when a problem is confirmed, daily while it lasts, and when it clears. `intuneget-watchdog status` lists current problems; `intuneget-watchdog test` sends a test post. |
| `deploy/intuneget-curated-refresh.sh` | Daily at 2:15 AM New York (installed as `/usr/local/sbin/intuneget-curated-refresh`, run by `intuneget-curated-refresh.timer`): downloads upstream's latest signed curated catalog into the app's data volume for patch 0011. |
| `.github/workflows/upstream-check.yml` | Weekly: newer upstream release? Test the patches on it and open the "Build upstream" PR (or an issue). |
| `.github/workflows/build.yml` | On `main` changes to `upstream-ref`, patches or branding: build `<tag>-hrm.<n>` and open the "Deploy" PR. |

## Registry and sign-in

- Images go to HRM's shared Azure Container Registry (Basic tier, private). Its address, and the IDs
  GitHub signs in with, are repo variables: `ACR_LOGIN_SERVER`, `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`.
  None of them is a secret, but keep registry and resource names out of files in this public repo.
- **Build:** an Entra app with a federated credential for this repo's `main` branch (it uses GitHub's
  immutable subject, `repo:<org>@<org id>/<repo>@<repo id>:ref:refs/heads/main`) holds AcrPush on the
  registry only. No client secret exists.
- **VM:** its system-assigned managed identity holds AcrPull on the registry only. The deploy script
  swaps it for a short-lived registry token per pull and deletes it afterwards.
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
- Run upstream's checks on the patched tree: `npm ci`, `(cd packager && npm ci --ignore-scripts)`,
  `npx tsc --noEmit -p .`, `npm test`. Compare any failures with unpatched upstream before blaming a patch.
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
- **Server alerts** come from two places. The VM watchdog (`intuneget-watchdog`) posts through the
  same signed flow (first URL in `WEBHOOK_MANAGED_IDENTITY_URLS`) when a problem is seen on two
  checks in a row, daily while it lasts, and when it clears; it is quiet during deploys. It can't
  report the VM itself being down, so a Cloudflare **Tunnel Health Alert** (Notifications, free on
  every plan) emails the IT Ops channel's email address when the tunnel goes degraded or down.

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
sudo systemctl enable --now intuneget-deploy.timer intuneget-check-updates.timer intuneget-send-notifications.timer intuneget-status.timer intuneget-watchdog.timer intuneget-curated-refresh.timer
```

## How we work

- Ask before every push to `main`, and say what it triggers: patch, `upstream-ref` or branding changes
  start a build; `deploy/version` changes deploy to production.
- Never merge a Deploy PR or change `deploy/version` without David saying so in that conversation.
- Third-party services stay in test mode; secrets only in GitHub secrets or root-only files on the VM.
- Update CHANGELOG.md for every change to what the server runs or how it deploys.

## Retire

When upstream fixes what the patches cover, run upstream's image (`ghcr.io/ugurkocde/intuneget:<tag>`):
point `IMAGE_REPO` in `/etc/default/intuneget-deploy` and the override at it, then archive this repo.

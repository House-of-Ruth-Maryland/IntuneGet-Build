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

- Webhooks are set up in IntuneGet under Settings → Notifications. For a Teams channel, create the URL
  with Teams Workflows ("Post to a channel when a webhook request is received"); leave the secret
  empty. The workflow runs as the account that created it, so use a shared IT account.
- Update notifications (patch 0003) go to the webhook owner's webhooks after each update check.
- Deployment results (patch 0006) go to **every** enabled webhook on the server as soon as a job
  finishes as deployed or failed. That's correct only while the server serves one Intune tenant.
- Messages carry app names, versions, staff emails, links and error text only; never add device,
  user or client details to them.

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
sudo systemctl daemon-reload
```

First time only, the cron secret (the app's `CRON_SECRET`) goes in a root-only header file:

```bash
sudo install -d -m 0700 /etc/intuneget
sudo sh -c 'umask 077; printf "Authorization: Bearer %s\n" "$CRON_SECRET" > /etc/intuneget/cron-auth.header'
```

Check, then enable:

```bash
sudo intuneget-deploy run && sudo intuneget-deploy status
sudo systemctl enable --now intuneget-deploy.timer intuneget-check-updates.timer intuneget-send-notifications.timer
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

# Changelog

## 2026-10-27

- cloudflared on the VM now updates itself nightly through apt. Its own updater had failed every
  night because it was installed from Cloudflare's package repository. The tunnel restarts only when
  a new version is installed.

## 2026-10-25

- Discovered Apps matches against the full catalog (about 15,800 apps), not just ~90 built-in ones, so apps
  like Intermedia Unite can be claimed. Close or uncertain matches become suggestions; nonsense
  suggestions such as McAfee for "UniFi Endpoint" are gone; Microsoft Store apps are labelled as such
  (patch 0009).
- Security release: Next.js 16.4.3 and other dependency updates close two critical and three high
  advisories (patch 0008).
- The deploy gate again blocks versions the catalog snapshot marks malicious or failed (patch 0001
  had skipped that check on SQLite servers).
- Teams Workflows posts are signed only for the exact flow URLs the server lists, and never follow
  redirects (patch 0007 had signed any Power Automate or Logic Apps URL).
- The VM deploy stops if its backup can't be made in full (disk space, failed copy), so a rollback
  can never restore an incomplete backup over the live data.

## 2026-10-24

- IntuneGet signs its posts to Teams Workflows with the server's Azure identity (patch 0007), so the
  IT Ops flow accepts only the IntuneGet server. No secret is stored.
- Deployment results reach Teams, Slack, Discord or custom webhooks (patch 0006): every deployed or
  failed app posts one message with its version, who deployed it and links to Intune and the GitHub run.

## 2026-10-23

- The server now upgrades itself from `deploy/version`: merging a "Deploy" PR backs up its data,
  switches the image, checks health and rolls back on failure.
- A weekly check opens a "Build upstream" PR for each new upstream release, with patch, test,
  migration-number and packaging-workflow results. Merging it builds the image and opens the Deploy PR.
- The VM runs `/api/cron/check-updates` twice a day and `/api/cron/send-notifications` after each.
- Webhook migration 9 keeps a webhook table created by earlier builds.
- Claim works for Webex, Wireshark, 1Password, Nmap, Brave, AnyDesk and DBeaver: patch 0004 corrects their
  WinGet IDs, and the weekly check now verifies every built-in app mapping against WinGet.
- Reports shows successful deployments (patch 0005): jobs packaged through GitHub finish as `deployed`,
  which Reports didn't count.
- When GitHub doesn't let Actions open a PR, the build and weekly check put a one-click
  "Create pull request" link in the run summary instead.
- The VM deploy script starts the app with its settings file (`.env.local`) and refuses to start it without one.
- Images now go to HRM's private Azure Container Registry. GitHub signs in with OIDC and the VM with its
  managed identity, so no registry password or token is stored anywhere. A weekly task keeps the 5
  newest versions.
- The update check runs at 03:30 and 15:30 New York time and notifications at 04:00 and 16:00 (the first VM timers ran both in the early morning only). `intuneget-deploy status` works when run by hand.
- Builds use IntuneGet v0.8.2 (patch 0001 rebased; patch 0003 updated).

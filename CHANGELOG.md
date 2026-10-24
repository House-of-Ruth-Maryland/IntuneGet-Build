# Changelog

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
- Builds use IntuneGet v0.8.2 (patch 0001 rebased; patch 0003 updated).

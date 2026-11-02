# Changelog

## 2026-11-02

- Deploy to Intune now shows a review first: one line per app saying what happens in Intune, which
  groups get it and how it installs, with warnings for an app with no groups or a second copy. Press
  Deploy now to send it, or Change to fix an app (patch 0025).
- Inventory lists apps with more than one copy in Intune. Keep this copy moves every group onto it and
  leaves the others with none (nothing is uninstalled); Delete from Intune then removes an emptied
  copy, after a confirmation (patch 0025).
- Safer updates (patch 0024, from a full logic review):
  - Updates keep the groups the app has in Intune right now. Before, groups added after the first
    deployment were lost at the next update.
  - Only the newest copy of each app is updated, and one update runs at a time, so Update All can't
    create duplicate apps.
  - Updates keep the app's New computer setup, categories and dependencies.
  - Deploy again replaces the current copy instead of adding a second app.
  - Save to Intune also saves the new-version choice; dependency changes ask for Deploy again.
  - A short catalog or GitHub outage no longer empties App updates or repeats alerts.
  - Update works even after automatic updates failed three times.
  - Install-failure alerts are only marked as sent once Teams accepted them, and a rise later in the
    day is reported the next day.
  - An update that can't start posts a failed-deployment alert.
- App updates only lists copies that still exist in Intune, and auto-update never acts on a copy that
  was deleted there (the extra Google Chrome and Zoom cards go away at the next check). Each card shows
  the groups that copy is assigned to. Inventory always shows Groups and warns when an app has none,
  because then it installs nowhere (patch 0023).
- Cleaner deploy panel: the main choices (who it installs for, which groups get it, what happens with
  new versions) are always shown, and every other option sits in two short lists, More settings and
  What staff see during install, each row showing its current setting. Labels and buttons are plain
  (Add to deployment, Save to Intune, Deploy again). All options are still there. Fixed: a New
  computer setup change on a deployed app was dropped by Update Settings; it now needs Deploy again
  (patch 0022).
- Fixed: an older copy of a custom app still in Intune (for example PdfCraft 0.10.1) also showed a new
  GitHub release in App updates. Only the newest copy is checked now, and custom apps are left out of
  Update All, since they are updated with Deploy new version (patch 0020).

## 2026-11-01

- Install results per app: twice a day, with the update check, IntuneGet reads how every app it
  deployed is installing (counts only, never device or user names). Inventory shows installed, failed, pending and not applicable with
  the most common reasons; Home lists apps with failures; an alert posts when an app's failures go up,
  at most once a day per app (patch 0019).
- New GitHub releases of custom apps show in App updates. Deploy new version opens the custom app form
  with the new version, download link and checksum filled in, for you to check. Nothing deploys on its
  own (patch 0020).
- Alerts can go through the HRM alert relay: Custom webhooks now include the server's address so the
  relay's cards link back to IntuneGet (patch 0019).
- Safer webhooks: addresses must be public https addresses, checked when saved and before every
  delivery, and redirects are never followed. Signed-in pages no longer contact changelog.ugurlabs.com
  (patch 0018).
- Server status shows the nightly off-site backup. Deploy new version only shows on the newest
  deployed version. The silent switches hint says they came from the previous version. Help covers
  install results, release alerts and the alert relay (patch 0021).

## 2026-10-31

- Moved to upstream IntuneGet v0.8.5 (from v0.8.2), which brings upstream's fixes since v0.8.2,
  including automatic-update history that completes reliably on SQLite servers. HRM's own version of
  that (in patch 0012) is dropped in favour of upstream's. All other HRM changes carry over.

## 2026-10-29

- The Cmd+K command palette works from the keyboard: the cursor is in its search box when it opens,
  and the arrow keys, Enter and Escape work. Its list matches the sidebar and includes Help (patch 0017).
- Dark mode is back: IntuneGet follows the computer's light or dark setting, and the account menu has
  a Theme choice (Light, Dark, Same as computer). Settings such as the theme are no longer reset on
  every page load (patch 0016).
- The server's database is copied off-site every night at 1:30 AM to a private Azure Storage
  container in another region and kept for 30 days. The watchdog alerts in Teams if a copy fails or
  is late.
- Safer deploys: the server checks each new image against the digest the build recorded, the build
  refuses an upstream tag that has moved since it was checked, registry tokens are no longer passed as
  command arguments, and the app's port is open only to the VM itself.
- New versions of custom apps: Inventory has Deploy new version, which fills in the form from the last
  version and keeps its groups and supersedence. IntuneGet warns before deploying an app with no
  groups, and a newer version found as a "duplicate" offers a clear Deploy and replace (patch 0015).

## 2026-10-28

- Help explains how to update WinGet, curated and custom apps. Discovered Apps pills no longer break
  mid-word, and sidebar and Inventory labels are sentence case (patch 0014).
- Teams deployment cards for updates name the person who pressed Update, or say "Auto-update" for
  scheduled updates, instead of "Unknown" (patch 0013).
- Update and Update All work on the server, and apps with auto-update on are updated by the twice-daily
  check. Each update replaces the previous Intune version and keeps its groups; held, skipped or
  failed updates say why. App Updates is back in the menu (patch 0012).
- The Curated Catalog works again and stays current: the VM downloads upstream's signed list daily and
  the app uses it when its signature checks out (patch 0011). The list built into v0.8.2 expired on
  2026-10-22.
- A watchdog on the VM posts to IT Ops in Teams when the app is unhealthy, a deploy fails, disk runs
  low, the update check or alerts fail or run late, or the tunnel stops; it posts again when the
  problem clears.

## 2026-10-27

- The server opens on an HRM Home page instead of the public IntuneGet website: what needs attention
  (updates waiting, failed or stuck deployments), recent deployments across HRM, server status
  (version, backup, update checks, disk, tunnel) and shortcuts (patch 0010).
- New Help page for HRM IT, and HRM Support on the sign-in page. SCCM, MSP and app-request menu items
  are hidden. HRM purple and teal replace the upstream colours.
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

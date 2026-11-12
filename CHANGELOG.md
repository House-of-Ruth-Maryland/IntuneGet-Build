# Changelog

## Unreleased

- Clearer screens after a UX review (patch 0058). Inventory tags an old copy that cleanup is
  holding Kept for review, and says which newer copy was deployed and when. The sidebar has two
  groups, Apps and Activity, with App updates under Apps and Help at the bottom. Home's Server
  status shows checks that need a look first, with the reason, and folds working checks into All
  checks. Needs attention buttons say where they go (Open app, Open Inventory, Open Deployments).
  App updates starts with one status strip for the Update schedule, Installation timing and
  Startup install results; Pause automatic updates is in Edit schedule, and Resume shows on the
  strip while paused. The No access page shows which account is signed in and has Sign in with
  another account. Deployments shows Sending to Intune instead of Uploading. Availability and
  deadline's button is now Reload dates. Status and error messages are shorter and never show raw
  error text. The IT dashboard report adds a "Limit IntuneGet sign-in to IT-Admins" to-do until
  the IT admins group is set. Home's Intune self-test reason now names the failed read only.
  David must reinstall `intuneget-status` on the VM (CLAUDE.md, "VM setup"). Remove and Retire
  screens say computers instead of devices (Remove from computers), and the deploy review says
  Updates: Auto-update. Help adds that groups carried to a new copy don't keep their availability
  date, deadline or restart grace; set them again with Availability and deadline. Help matches.

- Version sync after deploy. When a deploy finishes, the server corrects App updates straight
  away. If that fails after 2 or more deploys in 24 hours, Home's Server status shows Version
  sync after deploy as Failing, and IT Ops gets a Teams alert (daily while it lasts, and when it
  clears). The next deploy that corrects App updates clears it, and so does the 3:30 AM or 3:30 PM
  update check once it has rebuilt App updates (not when the catalog couldn't be read). New missed
  deploys raise it again by the same rule. If the app stops answering, the status file keeps a
  Failing verdict for up to 24 hours, or until a later update check succeeds, so the alert never
  clears by itself. The IT dashboard report and the MCP server's status show it too. Only a
  time, the app's WinGet ID and a short code are kept, never error text. David must reinstall
  `intuneget-status` and `intuneget-watchdog` on the VM (CLAUDE.md, "VM setup"). Help matches
  (patch 0057).

- Only HRM's IT admins group can use IntuneGet. With the group set on the VM (CLAUDE.md, "Access
  to the app"), staff outside the group, or from another tenant, see No access to IntuneGet and
  are asked to contact HRM Support. Every staff API call refuses them too. Adding or removing
  someone can take up to 5 minutes to apply. If the server can't check, the page says so and has
  a Try again button. No new Microsoft permission is needed. Until the group is set, nothing
  changes and Home's Server status shows "Not limited to a group" under Who can sign
  in. Cron jobs, the IT dashboard report, workflow callbacks and the MCP read API are not affected.
  The tenant setting is now `HRM_TENANT_ID` for both sign-in and the MCP read API;
  `MCP_TENANT_ID` still works when it is unset. Help matches (patch 0056).

- Read-only API for HRM's MCP server. The server answers questions from HRM's MCP server about
  server status, Needs attention, apps in Intune, App updates, the Update schedule, Deployments,
  install failures and Pilot rollouts. It sends app names, IDs, versions, counts, group names and
  error codes only, never staff emails, device names or error text, and it changes nothing. It is
  off until the five settings in CLAUDE.md ("MCP read API") are set on the VM, and it needs both
  the API key and the MCP server's Cloudflare Access service token. Contract: `docs/mcp-api.md`.
  Help matches (patch 0055).

- Inventory explains old copies. A copy IntuneGet has replaced shows a Previous copy tag. Its
  details say which version replaced it and when, and that it is removed automatically after 7
  days if it's safe. If cleanup is keeping it, the details say Kept: and why. Previous copies
  waiting for removal no longer also appear in the list of apps with more than one copy.
- Check installs now. Install results in Inventory has a Check installs now button that reads the
  newest copy's results from Intune straight away, instead of waiting for the 3:30 check. Each
  app can be checked once every 5 minutes. It changes nothing in Intune and never sends a Teams
  alert. Help matches (patch 0054).

- Easier navigation. In Inventory, each app's details now list its actions under one Actions
  heading: Availability and deadline first, then Deploy new version or Find in App catalog, then
  Go back to previous version, with Retire app last. The refresh icon at the top is labelled
  Reload from Intune. The sidebar now groups pages as Apps (App catalog, Inventory, Discovered
  apps), Updates (App updates), Activity (Deployments, Reports) and Support (Help), and Search
  lists them in the same order. Home shows one Deploy an app button instead of the Shortcuts card.
  New keyboard shortcuts: G then P for App updates, G then V for Discovered apps and G then H for
  Help. The Reports page is headed My deployment reports, since it shows only deployments you
  started. Help matches (patch 0053).

- One word for each job. Deploy now always means sending an app or a new version to Intune: App
  updates says Deploy new versions to Intune, the stat reads Deployed (7 days), and the Publishing
  history tab is now Update history. On App updates, Automatic update setup is now Automatic
  updates, the Automatic publishing card is now Update schedule (Edit schedule, Pause automatic
  updates, Resume automatic updates) and the Device installation card is now Installation timing,
  matching the deploy panel section that sets the same prompts and postponement. Inventory's date
  panel, which sets availability, deadline and restart grace for a copy already in Intune, is now
  Availability and deadline, with Reload from Intune and Save to Intune. The deploy panel explains
  where each setting lives. Help, its illustrations and its search match, and Settings Help now
  says plainly that this server has no update switches there (patch 0052).

- Clearer menu wording. App updates' step labels now read Step 1: Intune and Step 2: Computers.
  The deploy panel section Install behaviour is now Installation timing. The Claim all button in
  Discovered apps says Claim 3 apps instead of Claim 3 Apps. In Settings, General, Cart behavior is
  now Deployment list, and the Carry over assignments and Supersede previous version on update
  switches, which change nothing on this server, are replaced by one line linking to App updates,
  where update behavior is set. The unused Account page now opens Home. Home's All in tenant view
  says Activity for everyone in your tenant. Help matches (patch 0051).

- Deploy new version for custom and GitHub-release apps now replaces the previous copy the same way
  Update does: the new copy takes the groups the previous copy has in Intune when it deploys, and
  the previous copy is left with none. The review marks it Replaces current copy. Old-copy cleanup
  now waits 7 days from when each old copy was replaced, not from the newest copy's deployment, so
  apps updated more than once a week are cleaned up too. The newest copy still needs a successful
  install and no more than 1 in 10 failures. When the newest copy has been out 7 days with no
  groups, no installs or too many failures, Home now lists the old copies waiting on it with the
  reason. Help, the form text and the Inventory hint match (patch 0050).

- App updates, Home's count and the sidebar badge show the new version as soon as a deployment
  finishes, instead of listing the app as out of date until the next 3:30 check. This works for
  every way of deploying: Update, Update all, Auto-update, App catalog, Deploy new version and
  pilots. Dismissed apps stay dismissed. Deployments refreshes App updates, Home and Inventory when
  a job finishes, App updates re-reads when you come back to the tab and every 45 seconds while a
  deployment runs, and Inventory re-reads when you come back after a minute. Refresh in App updates
  now cleans out-of-date entries for everyone in the tenant. Inventory still lists the previous
  copy until it is removed. Help says when each screen changes (patch 0049).

- Weekly upstream check picks the highest app release tag (vX.Y.Z) instead of GitHub's Latest
  release. Upstream now also publishes IntuneGet Packager releases (packager-vX.Y.Z) marked Latest,
  which made the check fail since November 9 and would have hidden the next app release.
  Nothing the server runs changes.

- App updates puts results first, then connected Automatic publishing and Device installation cards.
  State rows, expandable details and compact Beta reporting replace the stacked explanation panels.
  The overview explains the 3:30 version checks and distinguishes per-app Auto-update from shared
  publishing-hour restrictions. A separate Pause/Resume control holds new automatic publishing and
  pilot starts/approvals without disabling discovery, clearing the schedule or stopping already
  queued work. Manual Update and Update all remain overrides. Help and illustrations match;
  SQLite migration 23 stores the tenant pause flag (patch 0048).

- Help redesigned around tasks: 22 searchable guides in five categories, with one workflow open
  at a time. Short steps drive an annotated example illustration, with prerequisites, expected
  outcomes, troubleshooting and related links. Detailed rules are grouped and collapsed.
  Existing bookmarks work, and app links open separately so users can follow along. Publishing
  and automatic-installation controls link directly to their guides. The Help checker validates
  illustration labels against the real app and rejects broken related links; maintenance rules
  and navigation/mobile tests are included. No new dependencies (patch 0046).

- Deployment history separates Cancelled from Failed and allows cancelled jobs to be dismissed.
  Clear history respects the selected outcome and only clears the signed-in user’s finished jobs;
  audit records remain. Dashboard activity uses a distinct cancelled outcome (patch 0047).

- Discovered-apps SQLite regression test uses a mocked catalog lookup instead of downloading
  the live catalog on clean CI runners. No application behavior changed (patch 0045).

- Test and delivery workflow: code PR revisions get one full patched-app check with
  app and packager compiler checks; description edits and Deploy-only PRs skip the suite.
  Added one local validation entry point with related/full modes, isolated scratch directories
  and bounded PowerShell fixture processes. Upstream checks cache npm
  downloads and include packager types; image builds cache layers. VM health and Windows Beta
  pilot checks remain separate. No production deployment settings changed.

- Install after next restart · Beta: an opt-in option in the deployment sidebars and per-app
  update exceptions. The shared packaging workflow stages a verified, protected local package and
  registers a SYSTEM task for a later startup, without forcing a restart or declaring staging an
  installation success. Restricted to machine-wide MSI/EXE apps outside new-computer setup.
  Startup reports in App updates distinguish waiting, installing, installed, failed, cancelled and
  outdated results; show last activity; preserve old snapshots on read failure; and generate a
  cancellation script for the exact package. The Intune Remediations reporting bridge requires
  eligible licensing, read permission and setup. IT dashboard summaries contain counts only.
  Cancellation remains available without reporting; incomplete reports show a warning. Original
  deployment order prevents older deliveries from replacing newer work. Startup eligibility checks
  include current deployment settings, and long-running installers retain coordination locks rather
  than being stopped by a launcher-only timeout.
  Startup Beta families are excluded from automatic old-copy cleanup. Help, rollout steps and
  the hourly reporting timer are included (patch 0044, SQLite migration 22). Windows pilot testing
  and deployment are still required; no users' tasks are created by this code change.

- App updates: an overview with right-side editors for a shared automatic installation policy,
  per-app exceptions, and the separate Publishing schedule. A new policy suggests 3 days to
  postpone; future automatic packages use the chosen rule, while manual updates, pilots and
  queued/published versions keep their settings. Postponement uses the installer toolkit and
  Intune retries, with no promise of an exact installation time. The toolkit may install silently
  without an active user or an app to close. Publishing history says Published to Intune and
  records the policy used for each release; expand a published release for device results, also available in Inventory. Installation timing
  for an existing version opens on the right from Inventory and App updates. Help explains setup,
  scope, inheritance and reporting limits (patch 0043, SQLite migration 21). The matching packaging
  workflow change and a Windows pilot are required before enabling prompted updates.

- Old copies of an app are removed from Intune automatically. At each update check, once an app's
  newest copy has been out for 7 days, has installed on at least one computer and has failures at
  10% or less, IntuneGet takes the groups off the older copies it deployed and deletes them. Only
  copies the newest one replaces and whose groups it already has are removed; nothing is
  uninstalled from computers. Copies it can't remove are listed on Home with the reason. Copies
  added in Intune by hand or deployed alongside are left alone. Help has a new How old copies are
  removed section (patch 0042, SQLite migration 20).
- Discovered apps: Remove from devices. A guided dialog checks whether IntuneGet can remove the app
  and, if not, says why and what to do instead. If it can, it adds a removal to the Deployment list
  (All devices or chosen groups, always Uninstall). Deploying adds "<name> (uninstall only)" to
  Intune, which uninstalls the program with exactly that name where devices have it, however it was
  installed, and never installs anything. Inventory then shows Removing this app with live counts
  and Delete from Intune (patch 0040, SQLite migration 19).
- Discovered apps: a How Discovered apps works panel shows the install and remove paths and what
  Claimed, To remove and each match status mean. Claim and Claim all say nothing changes on devices
  until you deploy. Help's Retire app section is corrected: retiring only removes copies IntuneGet
  installed (patch 0040).
- Inventory: the previous version's installer is checked at the 3:30 AM and 3:30 PM update checks,
  Maryland time (a light check of the link, never a download). Check installer now downloads it
  once and compares its SHA-256 without keeping it. A missing installer, a changed checksum or a link
  IntuneGet can't use (not https, or not a public host) hides Go back to previous version and lists
  the app on Home; a link that didn't answer can be retried. The review checks the link again before
  going back. Downloads only reach public https hosts, checked again at every redirect and connection,
  with size, time and two-at-a-time limits. Help explains the checks (patch 0039, SQLite migration 18).

## 2026-11-06 (v0.8.5-hrm.17)

- Inventory: Installation timing edits existing Win32 Required and Available assignments without
  repackaging. Set availability, a Required installation deadline, UTC or device-local time, and
  restart grace/countdown/snooze where supported. Live reviews reject stale changes and preserve
  other assignment settings. Save to Intune keeps live timing for unchanged group/intent pairs.
  Dates apply to this copy; offline devices can install later, and this is not a recurring
  after-hours window or startup/sign-in trigger. Help updated (patch 0041).

## 2026-11-06 (v0.8.5-hrm.16)

- Inventory: Go back to previous version. On the newest copy IntuneGet deployed, it redeploys the
  older version IntuneGet used before (same installer), replacing the current copy so Intune
  uninstalls the current version and installs the older one; the groups move over. Automatic updates
  then skip the version gone back from; Allow again clears that (patch 0037, SQLite migration 16).
- Inventory: Retire app. Every group changes to Uninstall, live counts show devices still reporting
  the app, and Delete from Intune removes it when they're done (or when confirmed anyway). Cancel
  retiring puts the groups back. Updates, pilots and deployments of the app are held while it is
  retired, and it is set to Ignore in App updates once deleted (patch 0038, SQLite migration 17).
- Help is now checked on every build. `scripts/check-help.mjs` fails the build, the weekly upstream
  check and PRs when Help names a button or heading the app no longer shows, or gives a time no VM
  timer runs at, and checks HRM's tooltips and hints for em dashes and "contact IT" (patch 0034 adds
  the label lists). PRs that change patches, `upstream-ref` or `deploy/` must tick "Help and tooltips
  checked" after running the help-writer agent.
- Help and tooltips audited against the running build and corrected (patch 0034):
  - Help no longer says the Settings switches Supersede previous version on update and Carry over
    assignments decide what an update does. On this server Update and automatic updates always
    replace the previous version and keep its groups; Help now says so.
  - Discovered apps uses the screen's labels (Partial match, No match, Link package). Teams alerts
    names Send test. Server status lists all its rows. Updating an app explains that auto-update
    turns off after 3 failures in a row, how the replace step shows supersedence, and the fallback
    when the catalog hasn't synced (Deploy again).
  - Hints fixed: the update policy picker no longer says assignments follow your settings, Save to
    Intune's hint includes new-version settings, "test group" is now "pilot group", the shortcut
    list says App catalog, install results say Maryland time.
  - Update all and Keyboard shortcuts are sentence case on screen.
- Under Update automatically, "Keep the same groups on each new version" is hidden on this server,
  because every update already keeps its groups. It still shows on a Supabase server (patch 0035).
- In Deployments, the button for a newer version of an app already in Intune says "and replace" only
  when the new version supersedes the old one, and "alongside" when both versions will stay in Intune.
- Find in App catalog in Inventory now opens the App catalog already searching for the app.
- UI cleanup (patch 0036), with Help rewritten to match:
  - The policy badge on an update card no longer says Auto-update after auto-update turned itself
    off (patch 0032's line and Turn auto-update back on button stay). The Auto-update on list marks
    those apps, and choosing Auto-update there or in the card's menu turns it back on.
  - Apps set to Ignore no longer appear in App updates. Ignored apps lists them so they can be
    changed back. Pin version (the same as Ignore on this server) is offered only on Supabase.
  - The Critical banner, card, filter, sort and badge are hidden on this server, where they only
    repeated Major.
  - Settings: the Export and Data tabs, which did nothing, are gone; the email card that can't work
    here is hidden; Notifications is described as Teams alerts. The Account page link is removed
    (it repeated Settings and Home).
  - SCCM, App requests and MSP pages, already hidden from the menu, now redirect to Home.
  - Webhook cards, Custom webhook links and the IT dashboard all use the same server address
    (`NEXT_PUBLIC_URL`, or `NEXT_PUBLIC_APP_URL` if that's the only one set).
  - One name per thing: Deployments (not Uploads), Deployment list (not cart or Selected apps),
    Notify only / Auto-update / Ignore, Open in Intune, Search, Curated apps. Forced deploys in the
    list say Replaces current copy or Second copy.
  - Fewer duplicates: one warning instead of two for apps with no groups, one Save to Intune hint,
    one policy-change handler (failed changes always show an error), shared summary and Intune-link
    helpers. The cart editor's Advanced row now notices edited commands.
  - Update schedule and Pilot rollouts sit under the App updates title; Pilot rollouts shows only
    while a pilot runs. Reports says it shows only your own deployments. Sentence case throughout.

## 2026-11-05 (v0.8.5-hrm.14)

Production runs v0.8.5-hrm.14.

- Help matches the screens again: deploying, replacing a version, the alert test button (Send test) and the
  Discovered apps badges. Long help points are split (patch 0033).
- Staff screens use sentence case: Partial match, No match, Link package, Link WinGet package,
  Claim discovered app, Keyboard shortcuts, Microsoft Store app, SCCM migration and App requests. The
  pilot screens say "pilot group" and no longer say "promotes".
- The watchdog's self-test alert says "failed or is late", matching Server status, which also flags
  a self-test more than 26 hours old. Reinstall `intuneget-watchdog` on the VM to pick this up.

## 2026-11-05 (v0.8.5-hrm.13)

Production runs v0.8.5-hrm.13.

- The server's own Intune reads can't fail silently any more. Home's Server status shows Intune reads,
  Intune self-test and Scheduled updates, and IT Ops gets a Teams alert when install results or app
  activity fail at 2 update checks in a row, when the new daily read-only Intune self-test
  (7:15 AM) fails or is late, or when the hourly scheduled-update run fails or is late. The IT
  dashboard report shows the same (patch 0032).
- Home lists apps that reach no devices: deployed over 3 days ago with nothing installed, pending or
  failed in Intune. Check groups opens the app in Inventory.
- Auto-update now really turns itself off after 3 failed updates in a row (a new attempt used to reset
  the count). Installer-check blocks don't count. IT Ops gets one Teams alert, and the App updates
  card offers Turn auto-update back on, which clears the count.
- Inventory opens an app's details from a `?app=<id>` link (the change from PR #40, which no longer
  applied). Home and single-app install-failure alerts link straight to the app.
- The build reads the registry address and Azure sign-in IDs from repo secrets, so GitHub masks them
  in public run logs (the change from PR #10).
- The VM needs `intuneget-intune-self-test.timer` and the updated status and watchdog scripts; see
  CLAUDE.md, VM setup. SQLite migration 15.

## 2026-11-05 (v0.8.5-hrm.12)

Production runs v0.8.5-hrm.12.

- Install results work again. Microsoft removed the Intune report IntuneGet used
  (getDeviceInstallStatusReport), so every check since 2026-11-02 read nothing; it now uses
  retrieveDeviceAppInstallationStatusReport (patch 0031).
- App activity, Group changes to review, pilot start and pilot review work again. Intune rejected the
  app read because it selected displayVersion on the general app type (400 for every app).
- The update check's result now includes a short reason (status codes only) when install results or
  app activity can't be read, and the server logs it, so a failure like this is visible.
- Deployment cards for jobs that never started show the real stage and reason. An installer that
  failed its check before packaging (publisher serves different bytes, version withdrawn from WinGet)
  is shown as Validation with its own code instead of Auth and a network hint, and every card shows
  Details with the recorded reason, including older jobs.
- Automatic updates no longer retry, at every check, a version whose installer already failed that
  check. They try again when the catalog offers a different version or WinGet corrects the checksum.
- Help explains these failures in Updating an app and When something goes wrong.

## 2026-11-05 (v0.8.5-hrm.11)

- Production runs v0.8.5-hrm.11 with the update schedule; the hourly timer is installed on the VM.

- App updates has an Update schedule card. Staff can choose the days and hours (Maryland time) when
  automatic updates and pilots may start, and add blackout dates (for example Month-end close) when
  they never start. Updates found outside the schedule wait, and a new hourly VM timer
  (`intuneget-start-updates.timer`) starts them once it opens. Deploy to pilot group and Approve wider
  rollout are refused while closed. Update, Update all and App catalog deploys still work at any time
  (patch 0030, SQLite migration 14). No schedule means no change.
- Screen labels use sentence case: App catalog, App updates, Discovered apps (the Discovered apps page
  heading said Unmanaged Apps), Available updates, Critical updates, Auto-update on.
- The VM needs the new timer installed and enabled; see CLAUDE.md, VM setup.

## 2026-11-05

Production runs v0.8.5-hrm.10.

- App updates can Test with a pilot group for deployed WinGet and curated apps. The new version is
  Required for 1 selected security group; the previous copy keeps its groups. Other deployments and
  automatic updates for that app stay held during the pilot (patch 0029, SQLite migration 13).
- Pilot rollouts compares app-wide installation results for both versions and shows the live groups
  before Approve wider rollout. Approval requires an explicit review, refuses a changed group list,
  and copies intent, exclusions, filters and settings to the new copy. It leaves the previous copy's
  groups intact; Inventory duplicate cleanup remains separate. Nothing promotes automatically.
- Pilots need SQLite with GitHub packaging. Custom apps, Store apps and apps with saved New computer
  setup profiles are excluded from this first version. A failed pilot stays held until its workflow
  is confirmed finished unsuccessfully and no copy remains in Intune; an unstarted stale reservation
  can be ended after 2 minutes. Help includes the controls, limits and a step diagram.

- Inventory has App activity: the latest 100 deployment, version, group and installation-count events
  across versions of an app. Existing deployment history appears immediately; observed changes start
  with this release. Save to Intune and duplicate cleanup record known group edits (patch 0028).
- Installation failures have What to check: suggested next steps for detection failures and common
  installer errors, with Microsoft troubleshooting links and general guidance for other codes.
- Inventory has Group changes to review for changed assignments, no groups receiving installations
  or a missing newest copy. The twice-daily check and Check now compare successful Intune reads;
  failed or partial reads keep the last successful state. Compare Previously / Now, then Mark reviewed
  without changing Intune. Missing and unassigned warnings stay until fixed. Saved warnings also show
  in App updates and replacement deployment reviews. Adds SQLite migration 12 and updates Help.

- Harden the IT dashboard report: authenticate before its per-key cache, always return empty 401
  for invalid credentials and 200 for authenticated reports, and sanitize all build failures.
  Cancellable SQLite aggregate reads use a separate read-only connection with a short busy timeout;
  slow builds return the last safe report within the response budget. Enforce version, link, text
  and size limits, count UTC calendar days, and omit waiting deployments from completed updates.

- IntuneGet publishes a status report for HRM's IT dashboard at `/api/status-report`: server
  problems, failed and stuck packaging jobs, and apps deployed per day. Counts only, behind its own
  report key (patch 0027). Needs `STATUS_REPORT_KEY` on the VM and a Cloudflare Access bypass for
  that path before the dashboard can read it.

## 2026-11-03

- Delete from Intune now works for copies that another copy of the same app replaces: it removes that
  link first. If a different app replaces or depends on the copy, it stops and names that app. Errors
  show Intune's own reason, and an expired sign-in says to reload the page (patch 0026).

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

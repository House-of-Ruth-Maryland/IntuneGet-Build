# Who gets an app, when it installs and how it updates

One page, in plain words, traced from the code of v0.8.6-hrm.5 (November 26, 2026) plus this repo's
Unreleased changes (the menu clean-up and item 122: Edit groups and install dates in the deploy
form). Where a name changed, the hrm.5 name is in brackets. "Unreleased" marks what hrm.5 does not
have yet.

## The four questions

**"App updates? Is this where the app installs from the publisher?"**
App updates is where new versions arrive, not where an app is first installed. Twice a day
(3:30 AM and 3:30 PM, Maryland time, fixed on the server) IntuneGet compares each app in Intune
with the publisher's catalog and lists the apps that have a newer version. The same check starts
the deployment to Intune for apps set to Auto-update, when the publishing window allows. On that
page you choose, per app, Auto-update, Notify only or Ignore, press Update or Update all, set the
days and hours IntuneGet may deploy automatic updates to Intune (or pause them), and choose how
automatic updates install.
A first install starts from Apps, App catalog. App updates does not decide who gets an app or its
install dates. The Settings card that was also called "App updates" only stated the check times; it
is now a plain line under "Not set on this page".

**"How do you change where the app installs for the user?"**
Who gets an app is a list of groups, each Required (Intune installs it) or Available (staff pick
it in Company Portal).

- New deployment: the deploy form's "Who gets it" section (All devices, All users or Entra groups,
  with Required, Available, Uninstall or Update only, exclusions and filters).
- App already in Intune: Apps, open the app (the app workspace), Current release, **Edit groups**
  [hrm.5: "Edit assignments", which only added a group]. Unreleased: it adds a group, removes a
  group, or switches a group between Required and Available, for any Win32 app in Intune. Each
  change is reviewed, then Save to Intune. One group is changed at a time and every other group
  keeps its filter, dates and settings exactly.
- In hrm.5, removing or switching a group meant App catalog ("Editing a deployed app", Save to
  Intune, for apps you deployed) or Open in Intune. Those still work but are no longer needed.
- Exclusions, Uninstall groups and groups that come from another assignment are changed in Intune.
  Inventory's "Group changes to review" shows changes made in Intune after the next check.
- An update keeps the groups of the version it replaces.
- If the question is per computer or per user: the deploy form's install scope ("Everyone on the
  computer" or "Signed-in user only") is built into the package. Changing it means deploying again.

**"What if the app already exists?"**

- IntuneGet deployed it and a newer version is out: Update (or Auto-update) replaces the previous
  version in Intune and keeps its groups. The old copy is removed later, once the new one has
  healthy installs for 7 days.
- You deploy an app from the catalog and Intune already has it: Deployments stops and says so.
  For a newer version it offers to deploy it as the replacement. For the same version it shows
  "Duplicate app already exists in Intune" with View existing app, or you can add a second copy
  and later press Keep this copy in Inventory.
- It is in Intune but IntuneGet did not deploy it: it still appears in Inventory, and Edit groups
  and Install dates work on it. Updates need IntuneGet to recognise the app; otherwise the app workspace
  says it cannot update it.
- It is installed on computers but not in Intune: Discovered apps, Claim.
- A computer that already has the version: Intune's detection rule reports it as installed and
  does not install it again.

**"Can you change when it installs after the fact?"**
Yes, in the released version. Apps, open the app, **Install dates**. For each group you can change
Available from, Must install by (Required groups only), the time zone (UTC or each computer's own
clock) and the restart grace period, then Save to Intune. Computers that already have the version
are not affected. The dates belong to the version in Intune now. Unreleased: a new deployment can
also set them up front, under Who gets it in the deploy form (Set install dates, per group). Blank
is still as soon as possible. In hrm.5 a new deployment has no date fields. When an update replaces a
version whose Required deadline has already passed, it pauses for IT to confirm the deadline
(Review deadlines in Deployments).

## Where each thing is set

| What | New deployment | App already in Intune | Future updates |
|---|---|---|---|
| Who gets it (groups, Required or Available) | Deploy form, Who gets it | App workspace, Edit groups: add, remove or switch (unreleased; hrm.5 only adds) | Same groups as the version replaced |
| Install dates (Available from, Must install by, restart grace period) | Deploy form, Who gets it, Set install dates, per group (unreleased; hrm.5 has no fields). Blank starts as soon as possible | App workspace, Install dates, per group | Carried to the new version from Intune. A passed deadline pauses the update for IT. Dates typed in the deploy form are not reused |
| New versions (Auto-update, Notify only, Ignore) | Deploy form, When a new version comes out | App updates, on the app's card | App updates |
| When automatic updates deploy to Intune (days, hours, pause) | Does not apply | Does not apply | App updates, Edit publishing window. All apps |
| Staff postponement and prompts | Deploy form, Postponement (built into the package) | Fixed in the package. Changes with the next version | App updates, How automatic updates install [hrm.5: "Installation timing"], Edit shared policy. One app: app workspace, Change how it installs [hrm.5: "Edit next rollout"] |
| New version checks | Fixed: 3:30 AM and 3:30 PM, Maryland time | Fixed | Fixed |

## Staff postponement, in full

- In a deployment: Postponement in the deploy form (days, a count or a date). It only shows when
  the installer toolkit runs with its windows; a silent package never asks.
- For automatic updates: one shared policy for all apps with Auto-update on, with app exceptions.
  The choices are Let users install now or postpone (1 to 14 days, counted from each computer's
  first attempt), Install automatically, and Use each app's saved settings. Install after next
  restart (Beta) is offered only where the server has the startup capability; HRM's server does not.
- Manual Update and pilots keep the settings reviewed at that time.
- Three different things are easy to confuse: Install dates (Intune decides when), postponement
  (staff decide, inside the package) and the restart grace period (time before a restart after
  installing).
- Timed reminders for postponement (PR 105) are a draft and are not in the released version.

## Released or not

- Adding a group ("Edit assignments", item 106): merged in PR 98 and running in v0.8.6-hrm.5. It
  adds a group only. The `edit-app-assignments` workspace holds the same work uncommitted; it has
  nothing newer than `main`.
- Install dates: released and editable.
- Edit groups (item 122: remove a group, switch Required and Available): built in this repo's
  Unreleased changes, not deployed. Tested against fake Intune responses only; check the first
  switch in Intune.
- Install dates in the deploy form (item 122): built, not deployed. It appears on HRM's server
  only after the private packaging workflow is updated and `HRM_DEPLOY_DATES_CAPABILITY` is set.

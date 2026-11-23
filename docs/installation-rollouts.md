# App workspace and rollout settings

Home, Apps, Updates, Activity and Settings are the primary navigation. Apps retains Inventory,
App catalog and Discovered apps; Activity retains Deployments and Reports. Existing routes,
bookmarks, permissions and keyboard/search aliases remain available. App names open the workspace;
Details opens the existing Inventory dialog. The workspace separates install results, the current
release, the next automatic update and secondary activity/details. Edit next rollout changes saved
future settings; it does not queue a job or edit the current copy. Unsaved changes stay in the editor.

Current release shows the actual selected version, assignments, install dates, recorded installer
behavior and reported outcomes. Missing timing or installer evidence stays unknown. Install now
from Company Portal remains an Optional assignment path. Required installation timing follows
Intune availability/deadline and check-in; offline devices have no guaranteed completion time.
Restart grace applies after installation and does not postpone installation.

The next automatic rule can inherit shared settings or use an app override. Existing mode keeps
saved app behavior; Silent suppresses postponement prompts; Prompt uses the existing PSADT
per-device deferral clock. The employee preview describes the effective rule briefly. It offers
no speculative time picker, dual cutoff or restart fallback. These employee choices remain deferred.

## Paired packaging capabilities

New workflow-dependent behavior is default off. Configure these server attestations only after the
matching packaging code has been reviewed, delivered and verified; no client request can enable them.

| Setting | Exact value | Effect |
|---|---|---|
| HRM_ASSIGNMENT_REVIEW_CAPABILITY | preserve-settings-v1 | Offers read-only single/bulk review and enables assignment-date checks for new replacement jobs |
| HRM_STARTUP_PILOT_CAPABILITY | natural-boot-v1 | Allows the app-scoped restart Beta alongside existing GitHub, package, group and account checks |

Without the assignment capability the existing manual/bulk flow is preserved. With it, review shows
version, saved or Curated settings, live assignment intent and group-paired dates. Empty live groups
stay empty. Past/device-local dates require keeping current dates or explicitly resetting both dates
to ASAP. Review starts nothing. Send update to Intune starts one update; Update all starts the batch.
A digest binds catalog/configuration/current app/assignment evidence. Packaging rereads all assignment
pages and rejects a changed snapshot. Supported notification, download, install/restart and optional
update settings, intent, exclusions and filters survive replacement; resetting dates changes only
installTimeSettings. Unsupported or incomplete reads stop carry-over. Automatic replacements with
past/device-local dates are held for review without counting a deployment failure. Previous groups
are removed only after successful new assignment application under the existing replacement policy.

The local packager uses packager/src/assignment-settings.ts. The GitHub path requires the paired
private workflow and assignments/Preserve-AssignmentSettings.ps1; the app-side .github/scripts copy
is the tested reference, not an automatic deployment to that private repository. An app-only release
must not attest the private workflow capability. Rollback and legacy jobs preserve their separate
behavior unless their job explicitly carries the review contract.

Restart Beta requires an explicit selected pilot security group before saving, and a separate Start
restart pilot action. Saving starts nothing. The job targets only that pilot as Required, stages first
and installs after a later device startup; it never forces reboot. Existing wider assignments remain.
Broad automatic dispatch is held for a saved restart rule. Unsupported package/setup/detection
configurations are rejected server-side. Legacy saved rules remain stored when capability is off.
The corrected helper uses an undelayed boot trigger, readiness wait and cleanup outside its payload
working directory. Natural automatic launch/exactly-once harmless installation/detection/cleanup were
observed in a local Windows VM, including a backward clock change; this is not real Intune delivery
validation. No startup deadline fallback, shutdown installation or before-sign-in guarantee is claimed.

## Discovery and publishing

Settings > App updates > Check for new app versions describes catalog discovery at 3:30 a.m. and
3:30 p.m. Eastern. Updates reports last-check evidence and the next expected check; expected cadence
does not prove timer execution. When can IntuneGet send automatic updates to Intune? controls the
separate automatic publishing window. Device installation follows assignments and installer behavior.

Cmd-K retains old terms and adds workspace, discovery, publishing and installation aliases. Scoped
review links navigate to the app sections; they do not start writes. Help uses the same current/next,
read-only review and explicit save/start distinctions. MCP adds saved current/next read summaries and
version discovery without adding deployment or group-changing authority.

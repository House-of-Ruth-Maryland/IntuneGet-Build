# Installation settings: verified behavior

## Decision locations and boundaries

The inventory below is source-traced. Interactive verification concentrates on changed
editors and their transitions; it is not a claim of live execution for every menu.

| Decision | Location and persistence | Effect and boundary |
| --- | --- | --- |
| Installer and execution defaults | App catalog, Custom app, Deployment list; cart draft then job snapshot | Vendor switches and toolkit mode are separate. Store and curated execution paths retain their restrictions. |
| Existing copy | Apps → workspace → Current release | Install dates changes supported assignment timing in Intune. Repackaging changes package behavior. An unsaved draft changes neither. |
| Add a recipient group | Current release → Edit assignments → Review assignment → Save assignment | Adds one Required or Available security-group assignment to the existing Win32 copy, with default timing and all notifications. Preserves other assignments, filters and unknown fields without replacing the collection. |
| Future automatic updates | Edit next rollout → Save for this app, or shared settings | Saves future automatic-update policy. Does not repackage the current copy, deploy a pending manual update or start the restart Beta pilot. |
| Manual/bulk replacement | App updates; effective review when capability is enabled | Configuration and assignments are reviewed separately. Expired required deadlines need explicit retain/new-date confirmation. Stale timing reviews stop packaging. Legacy and automatic paths enforce the same hold. |
| Automatic update window | Settings and App updates | Governs sending versions to Intune, not device installation. Catalog discovery cadence is informational and separate. |
| Outcomes | Activity → Deployments; workspace → Install results | My deployments is owner history. All in tenant includes authorized owners within the newest 50 unarchived records. Installation results are separate endpoint evidence. |
| Failure recovery | Error details, support ID, review and safe retry | Assignment review is not file validation. Legacy deadline codes can also mean unsupported or unreadable assignments. Preserve the reason; do not infer expiry or accept unknown fields. |

### Other application decisions kept intact

| Surface | Decision, default and storage | Backend/visibility boundary |
| --- | --- | --- |
| Home | Read current health, attention counts and activity; follow scoped links | Reads server/database status, not an installation command or endpoint success claim. |
| Apps → Inventory | Search/publisher filters and pages; select a current copy | Win32 Graph inventory is shared through the configured tenant identity after app admission. It is not owner-only deployment history. |
| App workspace | Current release, next automatic update, actual results and activity | Current-copy edits, future saved policy and observed outcomes remain separate; unknown/read errors are not treated as empty successful results. |
| App catalog / Custom app | Installer identity, architecture, scope, commands, detection, dependencies, enrollment setup and category | Draft selection becomes a persisted cart entry, then a packaging-job snapshot. Tested curated execution defaults retain their restrictions; Store packages bypass the Win32 toolkit. |
| Discovered apps | Match/claim or hide a discovered entry | Claim prepares a deployment draft; it is not proof of a new installation. Existing deployment/history checks prevent duplicate claims. |
| Updates | Notify only, Auto-update or Ignore per app; saved deployment configuration | Automatic publishing resolves shared/app installation policy. Manual/bulk review and assignment carryover retain their separate admission and capability checks. |
| Activity | Personal/tenant scope, status filter, dismiss or clear finished history | Default personal scope; owner-only archive controls. No new permission follows from tenant-wide read visibility. |
| Settings → General | Account/connection, catalog checks and update behavior | Account/tenant identity comes from authentication. Discovery times are informational; SQLite/Supabase-specific update settings retain their existing visibility. |
| Settings → Permissions | Inspect Graph permission/consent status | Displaying a check does not grant permission. This PR changes no identity, consent or access configuration. |
| Settings → Notifications | Email where supported, webhook configuration | SQLite hides unsupported email controls. These administrative alerts differ from toolkit balloons and Intune employee notifications. |
| Settings hidden panels | Export/data mock panels remain unreachable | No newly actionable fake export or data deletion control. |
| Help and Search | Stable task IDs, route links, old/new search terms and current control labels | Navigation and explanation only. Search does not bypass the destination's server authorization. |

Source locations: `app/(app)/dashboard/{page.tsx,inventory,apps,unmanaged,updates,uploads,settings}`,
`components/{CartItemConfig,PackageConfig}.tsx`, `components/hrm/{AppWorkspace,InstallationPolicyPanel,EditAssignments}.tsx`,
`lib/hrm/{navigation,manual-update-review,installation-policy,install-experience,settings-summary}.ts`,
`lib/github-actions.ts`, `lib/auto-update/sqlite.ts`, `packager/src/{assignment-settings,job-processor}.ts`
and the corresponding authenticated API routes. Defaults and effective values are tested separately
from saved inactive values; visibility alone is never treated as authorization.

Application admission, tenant resolution and deployment permissions remain server-enforced. Tenant history does not grant another owner's mutation rights. Assignment saves recheck app/group identity, retirement/pilot holds and conflicts. An uncertain save must be rereviewed rather than automatically posted again. Readback uncertainty remains an error.

Current main includes replacement-deadline review and its paired workflow contract. App/local diagnostics now report bounded field names only and still reject unknown settings, including null or false. The corresponding private hosted diagnostic remains a separate dependency; the rejected live field is unknown.

Rendered screens and route/script tests use isolated synthetic responses and harmless fixtures. They do not establish new Windows prompt behavior or successful Intune delivery. Prior local startup proof is separate from the pending scoped pilot. No time picker, dual cutoff, restart fallback, production flag change or broader pilot scope is introduced.

Audit baseline: the patched server source and the current private GitHub workflow were read without changing production. The workflow pins generator `9214e4b5b71508bfba9aa1a2d4de5c3c771d3fea` and PSADT **4.1.8**. The local packager is a separate implementation. Newer PSADT documentation is not substituted for this pinned runtime.

## Decision map

| Decision | Saved setting and code | Actual effect and limits |
| --- | --- | --- |
| Vendor installer arguments | Cart item `installCommand`, optional `psadtConfig.installCommand`; `lib/github-actions.ts`, generator installer dispatch, `packager/src/job-processor.ts` | Installer switches and overrides are independent of wrapper mode. Silent toolkit mode does not rewrite an arbitrary vendor command into a silent command. Reviewed vendor adapters can replace arguments. |
| Toolkit windows | `psadtConfig.deployMode`; workflow command construction; local `IntuneUploader.buildCommandLines` | Silent passes `-DeployMode Silent`; NonInteractive passes that mode; Auto omits the flag. These are PSADT modes, not vendor installer display modes. |
| Silent toolkit | PSADT 4.1.8 `DeploymentSession.cs:899`, `Show-ADTInstallationWelcome` | Suppresses generated toolkit dialogs. Configured processes can still close without a question and disk checks still execute. It does not suppress Company Portal/Intune notifications or arbitrary vendor windows. |
| NonInteractive toolkit | PSADT `DeploymentSession.cs:903`, progress/prompt/balloon/restart functions | Close/deferral and custom question dialogs are suppressed. Progress requires its own enabled flag. Balloon notifications and the pinned 4.1.8 restart prompt are separate and may still appear; it is not necessarily “a progress window only.” |
| Auto toolkit | PSADT `DeploymentSession.cs:736–906` | Toolkit chooses interactive versus silent from session, OOBE/ESP and configured running processes. No signed-in user or a configured process list with none running can make it silent. This is not “let the installer decide.” |
| Close apps | `processesToClose`, `showClosePrompt`, countdown, `blockExecution`; both generators' process lifecycle | Only listed processes are managed. Silent/NonInteractive welcome handling closes them without a question. Auto can ask when interactive. Deferral with processes uses `AllowDeferCloseProcesses`; without processes it uses `AllowDefer`. Save-work, persistence and placement options require an interactive welcome. |
| Remove existing app | `removeExistingInstall`; generator `Get-ADTApplication` and uninstall loop | Registered-app name matching uses Contains. Removal is best effort: failures are logged and installation continues. This is not an exact-product fleet remediation. |
| Verify installed app | `verifyInstall`; generated post-install registration check | Adds a registered-app name check. Package-specific detection and mandatory adapter checks can still apply separately; disabling this switch does not disable every detection rule. |
| Postpone | `allowDefer`, count, days, deadline; generator welcome parameters; PSADT defer history | Allowed only during an interactive welcome. An attempt count can accompany one time limit. The toolkit stores a single deadline; an explicit date can overwrite the relative day deadline across attempts, so combining both is not a reliable earlier cutoff. A stored count is inactive when `allowDefer` is false or the toolkit is silent. Return1602 is mapped to retry by the GitHub workflow. No employee time picker or bounded restart fallback exists. |
| Free-space check | `checkDiskSpace`, `requiredDiskSpace`; welcome call and toolkit free-space branch | Runs before installation even in silent mode. Without an explicit minimum the toolkit calculates a source-size requirement. Insufficient space stops the deployment; a visible error depends on interactive mode. This belongs with background checks, not staff messages. |
| Progress/messages/notifications | `progressDialog`, enabled `customPrompts`, enabled `balloonTips`; GitHub generator | Calls are generated only when enabled. Silent suppresses their UI; NonInteractive suppresses custom prompts but permits configured progress/balloons. No signed-in user can prevent visible UI. Intune assignment notifications are separate settings. |
| Restart through Intune | `restartBehavior`; workflow `deviceRestartBehavior` | Suppress maps to `suppress`; Prompt maps to `basedOnReturnCode`, not an unconditional staff prompt; Force maps to `force`. Assignment dates/grace/notifications are separate current-copy settings. |
| Package restart countdown | `restartPrompt.enabled`; generator post-install `Show-ADTInstallationRestartPrompt` | A separate generated post-install call, not conditioned on a reboot-required installer result. In pinned4.1.8 it can show in NonInteractive mode, and without a user it can schedule a silent restart. Silent skips it unless explicitly forced; this generator does not pass SilentRestart. Do not equate it to Intune restart grace. |
| Branding | Company, accent, images, welcome message; generator toolkit config | Used only by toolkit UI when that UI runs; company metadata may also be used in logs. `brandingWelcomeTitle` is read into an unused variable and does not currently set `InstallTitle`. It must not be presented as an effective editable title. |
| Startup Beta | App-scoped gate, `installAfterRestartBeta`, staging helper | Stages first and installs after a later boot, without forcing reboot or blocking sign-in. Distinct from a restart after installation. Existing capability/pilot restrictions remain; no expansion is part of this redesign. |

## Persistence and precedence

PackageConfig adds a configured item to the persisted Deployment list. CartItemConfig edits that stored draft. Package requests store a package configuration snapshot on the packaging job. Editing a deployed application's installer behavior requires packaging again; the current-copy Save to Intune path only changes its supported Intune settings. None of these menus edits the code of an already packaged copy.

Manual single and bulk updates begin from each app's saved deployment configuration; review/carryover behavior depends on the validated workflow capability. Automatic updates additionally resolve the shared installation policy or app exception. Existing retains saved settings; Silent replaces the relevant prompt settings; Prompt applies the day-only rule and Auto mode; Restart applies the gated startup rule. Current and queued packages retain their snapshots. A per-app installer override and a shared automatic-installation rule are different scopes.

Curated tested defaults own execution settings; permitted appearance overrides do not imply permission to change tested installer behavior. Store apps bypass the Win32 wrapper. Removal packages have their own supported removal configuration. Required/Available group intent, availability, deadline, Intune notifications and restart grace are assignment behavior, not PSADT prompt settings.

## Confirmed path differences

The local TypeScript generator implements process handling, disk checks, install verification, commands and markers. It does not implement the GitHub generator's progress/custom prompts/balloons/branding/package restart prompt. Its uploader hardcodes Intune restart suppression. Its generated script defaults to Silent, so Auto's omitted flag currently leaves it Silent. These options must be gated or described as unavailable on that path; a menu redesign must not silently claim parity.

The private workflow's checked-in source differs from local unshipped workflow work. Local fixes and prior harmless Windows pilots are not proof of a newly delivered Intune package. No new endpoint experiment, reboot, tenant change or release was performed for this audit.

## Label mismatches to remove

- “Nothing, it installs silently” conflates toolkit windows, installer switches and Intune notifications.
- “A progress window only” promises a window with progress disabled and hides other possible notifications/restarts.
- “Let the installer decide” attributes PSADT context detection to the vendor installer.
- “All off” contradicts saved enabled fields and cannot summarize effective behavior.
- “Up to3 times” must not describe inactive postponement or hide day/deadline constraints.
- “Ask staff to restart” misstates Intune return-code restart policy and conflates it with the package countdown.
- Disk checks and process blocking remain background behavior in silent mode.

Primary runtime references: [pinned PSADT deployment session](https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/blob/4.1.8/src/PSADT/PSADT/Module/DeploymentSession.cs), [PSADT4.1 deployment guidance](https://psappdeploytoolkit.com/docs/4.1.x/usage/how-to-deploy), [pinned generator](https://github.com/ugurkocde/IntuneGet/blob/9214e4b5b71508bfba9aa1a2d4de5c3c771d3fea/.github/scripts/Create-PSADTPackage.ps1). Local paths above refer to the reconstructed source; public patches preserve their file ownership.

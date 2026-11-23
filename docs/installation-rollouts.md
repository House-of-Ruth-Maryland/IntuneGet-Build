# App workspace and rollout editing

Open an app workspace from Inventory, App updates or a Deployment with a recorded Intune app ID.
The workspace lives at `/dashboard/inventory/[appId]`. It reuses authenticated inventory, app
observations, saved deployment configuration, installation policy, pilot and install-result APIs.
Current-copy configuration requests include the exact Intune app ID; a missing configuration is
shown as unavailable instead of substituting the newest version. Automatic policy editing is
limited to the signed-in tenant and the existing server-side account/app authorization.

Current copy shows the selected version, saved installer behavior, live groups, Install dates,
reported installation outcomes and app activity. Next automatic rollout shows the effective saved
shared rule or app exception. Edit next rollout opens the existing persisted installation policy
editor for that app. It does not queue a release or rewrite the current package. Unchanged settings
cannot be saved; editing produces Unsaved changes, and closing discards the local draft. Restoring
inheritance removes the app exception through the existing API. Manual Update, Update all and
pilots retain their own package configuration.

The existing PSADT postponement rule is relative to each computer's first installation attempt.
It is custom installer behavior, not native Intune employee scheduling. The existing startup Beta
has no forced restart, sign-in gate or enforced deadline fallback. This change does not alter its
installer, task or return-code handling. A Required assignment's date does not guarantee a device
will finish while offline, and post-install restart grace does not postpone installation.

Employee time selection, a 72-hour period bounded by an earlier absolute IT cutoff, and a startup
preference with a cutoff fallback have no validated device capability in this build. The employee
preview therefore explains the saved rule and disables those proposed actions. No override, tenant
flag or preview fixture can activate that enforcement. A separately reviewed, validated Windows
pilot and matching external packaging workflow would be needed before implementing it. This UI
does not claim installation during shutdown or before sign-in. Optional Available assignments
remain Company Portal self-service and do not acquire a Required deadline.

Settings > App updates > Check for new app versions describes the twice-daily discovery cadence.
App updates reports the last scheduled check attempt from fresh server status evidence, including
failure or missing evidence. Next expected timer check is calculated from the documented Eastern
cadence; it is not proof of an enabled timer or a confirmed queued job. Automatic delivery windows
and per-computer installation timing remain separate controls.

Known existing deployment limitation: ordinary replacement paths reconstruct assignment settings
when carrying over groups, so current-copy Install dates, notification settings and restart grace
must not be assumed to survive replacement. Pilot promotion uses a different full-settings copy.
This workspace exposes current versus future scope without changing those deployment semantics.

Search (Cmd+K / Ctrl+K) retains old terms as aliases and adds discovery, automatic delivery and
installation guidance. A concrete app workspace also offers Review next rollout and Review current
copy and install dates, linking to that app's sections without starting writes.

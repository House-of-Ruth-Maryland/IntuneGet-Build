# Replacement deadline hold (local, unreleased)

Item 80 selects **Pause for IT to confirm**. A replacement with a required deadline already
due pauses before packaging. Device-local wall times are treated as potentially due through
UTC+14; later dates, optional assignments, exclusions and ASAP deadlines are unaffected by
this hold. The existing separate past-date review can still apply.

IT chooses **Retain the existing deadlines** or **Choose a new deadline**. Rescheduling changes
only affected required deadlines. Availability, time-zone mode, target/filter, notifications,
delivery priority and restart grace remain unchanged. A future deadline must be at or after
availability; a device-local deadline must be more than 14 hours ahead to be future in every
civil time zone. Retaining a due deadline can cause installation at the next Intune attempt.

Manual and bulk review tokens bind saved configuration, source app, new installer and current
assignments. The server derives affected assignment IDs. Legacy deployments held before a
hosted run starts have **Review deadlines** in Deployments. Opening/cancelling reads only;
**Confirm and resume packaging** uses an atomic status/version check and normal dispatch.
An already-started hosted run uses **Retry safely** to stage a fresh job rather than reusing
its callback authority. Automatic updates cannot confirm on IT's behalf and create no job or
failure-count increment while held. A later manual update supplies the decision.

Current assignments are re-read at admission, on retries, in the hosted workflow before tool
downloads, and before assignment writes. A changed snapshot, newly expired assignment,
elapsed new deadline, unreadable source or incomplete pagination holds the replacement.
This is not a transaction across Intune reads and writes: an external change immediately
after the final read remains an ordinary Graph concurrency limitation.

## Release path

On November 25, 2026, David approved v0.8.6 with Curated publishing paused when current-hold
verification is unavailable. App PR99 and the factual Help correction PR100 were released as
v0.8.6-hrm.4 through [Deploy PR101](https://github.com/House-of-Ruth-Maryland/IntuneGet-Build/pull/101).
The compatible private workflow was checked separately. Assignment-review and restart Beta
capabilities remained disabled, and existing settings and explicit pilot targeting were preserved.
Application release does not itself enable a workflow-dependent capability or establish live
Graph write acceptance. Future activation requires its own readiness review and authorization.
`deploy/version` records the image target; deploy status and the running digest establish delivery.

Local validation covers real application functions and extracted hosted steps with harmless
fixtures and mocked Graph; it does not prove Intune delivery or device installation. The
initial item80 review reported a VirusTotal-hold baseline failure; that historical run was not
release sign-off. The later PR99 and PR100 full regression checks passed before this release.

Paired review: [app PR97](https://github.com/House-of-Ruth-Maryland/IntuneGet-Build/pull/97) and [workflow PR4](https://github.com/House-of-Ruth-Maryland/IntuneGet-Workflows/pull/4).

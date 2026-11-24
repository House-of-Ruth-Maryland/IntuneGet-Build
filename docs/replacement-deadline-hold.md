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

Nothing in this effort is pushed, merged, deployed or enabled in production. The production
pin remains hrm33. This review branch is reconstructed from current main (merged but undeployed v0.8.6) plus item80 only; item91 remains in its original local workspace. Do not release this tree as an implicit version upgrade.
An authorized release must first select an hrm33 backport or approve the integration separately,
then publish the matching private `IntuneGet-Workflows` admission/helper changes, deploy the
matching app and any local packager, and verify the effective workflow revision. Preserve all
existing feature flags, saved install choices and explicit pilot targeting.

Local validation covers real application functions and extracted hosted steps with harmless
fixtures and mocked Graph; it does not prove Intune delivery or device installation. The
full app suite has an unchanged VirusTotal-hold test failure also reproduced on the exact
pre-item-80 source. Resolve or separately accept that test failure before any release decision.

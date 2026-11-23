# Upstream v0.8.6 integration

The canonical server baseline is `ugurkocde/IntuneGet` v0.8.6 at
`cbafb23edf908b3fbd55d18b951fd38548b64f85`, following v0.8.5 at
`72ba1ec617004541a90bb9f04962ab0d30326a8b`. The independent `packager-v1.4.6`
release is not a server tag and does not update HRM's private GitHub packaging workflow.
That workflow retains its separately reviewed generator pin and capability gates.

## Database compatibility

HRM keeps migrations9–27 and their existing data. Upstream's callback-ownership migration9 is
relocated to28. A plain upstream v0.8.6 database at9 receives the idempotent HRM webhook step
before migrations10–28; existing HRM26/27 databases receive only pending additive changes.
Fresh installations and repeated starts use the same combined migration list. Callback ownership
starts null for legacy jobs; migration does not claim or restart a packaging job.

## Preserved behavior

Keep HRM's tenant authorization, pilot holds, app workspace/navigation, persisted settings,
discovery reconciliation and replacement workflow. Upstream refreshes current automatic detection
rules, fences callbacks by authenticated run/revision and retries unconfirmed dispatches with a
pinned payload. HRM's successful-deployment reconciliation runs only after an accepted write or
an authoritative completed-state read. Security dependency updates already present upstream are
not downgraded; HRM's remaining dependency overrides stay in place.

## Current Curated security eligibility

Upstream v0.8.6 requires a current exact-installer-hash security-hold read in addition to signed
Curated release approval. Its supported implementation reads `qa_installer_security_holds` using
the configured Supabase service client. It permits a verified current clean/released decision,
blocks an active hold and blocks missing, invalid or unavailable evidence.

The signed catalog supports approved and withdrawn release decisions, but does not replace this
mutable current-hold check. Public `/api/qa/status` supplies cached display evidence and does not
bind a current allow decision to an exact installer hash. Neither is accepted as a bypass.

The SQLite production service has no configured Supabase service client. Until a supported trusted
eligibility source is provided, this integration therefore holds Curated publishing. Ordinary
WinGet and custom-app paths retain their separate gates. Before deploying this upstream version,
review that availability impact and choose either to retain the previous server version or deploy
with Curated publishing held. A future supported current-eligibility feed must bind the exact hash,
carry freshness/expiry evidence and fail closed for held or unavailable results. Do not add hosted
credentials, invent an endpoint or weaken this check to make the upgrade pass.

## Release sequence

The reviewed navigation/MCP release is independent. Keep startup and assignment-review packaging
capabilities off until their paired private workflow is separately delivered and validated. Review
the upstream integration PR's reconstruction, upgrade/fresh-install, full regression, packaging,
MCP and production-build checks before merging. A new server deployment follows its own digest-pin
PR and live health verification; it is not proof of Windows or end-to-end Intune installer behavior.

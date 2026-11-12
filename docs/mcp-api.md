# MCP read API (patch 0055)

The IntuneGet server serves a small, read-only API for HRM's MCP server (the `hrm-intuneget-mcp`
Cloudflare Worker). The Worker turns it into tools that Claude can call. This page is the contract
both sides follow. Code: `lib/hrm/mcp-api.ts`, `lib/hrm/mcp-auth.ts` and
`app/api/hrm/mcp/[...path]/route.ts` in the patched tree. VM setup: CLAUDE.md, "MCP read API".

All examples use fake data.

## Rules for every endpoint

- **GET only.** No endpoint changes Intune, the database or any setting. Other methods get `405`.
- **One tenant.** Every answer is about the Intune tenant in `HRM_TENANT_ID` (or `MCP_TENANT_ID` when that is unset), never another.
- **Base path:** `/api/hrm/mcp`. Paths are below.
- **No caching:** every response has `Cache-Control: no-store`.
- **Deadline:** the server answers within 6 seconds (the Worker waits 8). If it can't, it
  answers an empty `503`.
- **Size:** answers are at most 256 KB of UTF-8 JSON. Bigger answers become an empty `503`.
  Lists are capped (see each endpoint), so this only guards against surprises.
- **Errors carry no text.** Every error has an empty body:

  | Status | Meaning |
  |---|---|
  | `400` | A query parameter or ID is not valid. |
  | `401` | Not authorized, or the API is not set up (see below). The reason is never given. |
  | `404` | Unknown path, or no such app in Intune. |
  | `503` | Intune or the database could not be read in time, or the answer was too big. |

- **Never in any answer:** staff emails or names, user IDs, tenant IDs, device names, raw error or
  status messages, Intune descriptions or notes, old-copy cleanup reasons, installer URLs, GitHub
  run URLs, or who approved, started or cancelled anything. Install errors are a normalized code
  (`0x87D1041C`) plus HRM's own fixed category text for codes HRM knows. Job errors are a machine
  code (`HASH_MISMATCH`) and category (`installer`) only.
- **Text limits:** names and labels are cut to 200 characters, versions to 60, with control
  characters removed. Times are ISO 8601 in UTC, or `null`.
- **Extra fields:** the server may send more fields than the Worker's schema lists. The Worker
  drops anything its schema doesn't name, so new fields reach Claude only when added there.

## Authentication

Every request needs **both** of these. Anything missing or wrong gets an empty `401`, and the
server reads nothing.

1. `Authorization: Bearer <MCP_API_KEY>`. The key has at least 32 characters and is compared in
   constant time, the same rules as `STATUS_REPORT_KEY`.
2. `Cf-Access-Jwt-Assertion: <JWT>`. Cloudflare Access adds this header after it accepts the
   Worker's service token (`CF-Access-Client-Id` and `CF-Access-Client-Secret`). The server checks
   the RS256 signature against the team's keys (`https://<ACCESS_TEAM_DOMAIN>/cdn-cgi/access/certs`),
   the issuer (`https://<ACCESS_TEAM_DOMAIN>`), the audience (`ACCESS_AUD`), the expiry, and that
   `common_name` equals the service token's client ID (`MCP_ACCESS_CLIENT_ID`). A person's
   Access login has no `common_name`, so it never passes.

The API is off (always `401`) unless all five settings are present and well formed:
`MCP_API_KEY`, `ACCESS_TEAM_DOMAIN` (must end in `.cloudflareaccess.com`), `ACCESS_AUD`,
`MCP_ACCESS_CLIENT_ID` and the tenant (a GUID). The tenant is `HRM_TENANT_ID`, which sign-in
also uses (patch 0056); a server set up before that can keep `MCP_TENANT_ID`, which is read when
`HRM_TENANT_ID` is unset.

Optional header `X-HRM-Requested-By: <email>` names the person who asked the Worker. The server
writes it to its own log with the endpoint name (`[mcp-api] GET jobs for person@example.test`),
only after both checks pass. Anything that is not a plain email is logged as `unknown`. It is never
returned.

## Endpoints

### `GET /status`

The server's own health, from the status file the VM writes every 5 minutes (same source as Home's
Server status card). No parameters.

```json
{
  "health": "degraded",
  "version": "v0.8.5-hrm.12",
  "generatedAt": "2026-11-03T11:58:00.000Z",
  "lastUpdateCheckAt": "2026-11-03T07:30:00.000Z",
  "lastBackupAt": "2026-11-02T10:00:00.000Z",
  "lastOffsiteBackupAt": "2026-11-03T05:31:00.000Z",
  "diskPercentUsed": 41,
  "checks": [
    { "name": "deploy", "state": "ok", "checkedAt": "2026-11-02T10:00:00.000Z" },
    { "name": "offsiteBackup", "state": "ok", "checkedAt": "2026-11-03T05:31:00.000Z" },
    { "name": "disk", "state": "ok", "checkedAt": "2026-11-03T11:58:00.000Z" },
    { "name": "updateCheck", "state": "ok", "checkedAt": "2026-11-03T07:30:00.000Z" },
    { "name": "notifications", "state": "ok", "checkedAt": "2026-11-03T07:35:00.000Z" },
    { "name": "tunnel", "state": "ok", "checkedAt": "2026-11-03T11:58:00.000Z" },
    { "name": "tunnelUpdate", "state": "ok", "checkedAt": "2026-11-03T00:00:10.000Z" },
    { "name": "intuneReads", "state": "ok", "checkedAt": "2026-11-03T07:30:00.000Z" },
    { "name": "intuneSelfTest", "state": "failed", "checkedAt": "2026-11-03T11:15:00.000Z" },
    { "name": "scheduledUpdates", "state": "unknown", "checkedAt": null },
    { "name": "versionSync", "state": "ok", "checkedAt": "2026-11-03T10:40:00.000Z" }
  ]
}
```

- `health`: `ok` (no problems), `degraded` (any check failed or disk is over 85%) or `unknown`
  (the status file is missing, stale or unreadable; then `statusFile` says `missing`, `stale` or
  `unreadable`, and `checks` is empty).
- `checks[].state`: `ok`, `warning` (disk only), `failed` or `unknown` (never run or not set up).
  `offsiteBackup` is left out on servers without off-site backups. A check's reason text is never
  sent.
- `versionSync` (patch 0057): `failed` when App updates wasn't corrected after 2 or more deploys in
  the last 24 hours, with no successful correction since. `checkedAt` is the newest recorded result.
- `version` is only ever a release tag like `v0.8.5-hrm.12`, otherwise `null`.

### `GET /attention`

Home's "Needs attention" for the tenant. No parameters. Each list has at most 50 items.

```json
{
  "counts": {
    "failedJobsLast7Days": 2,
    "stuckJobs": 0,
    "appsWithInstallFailures": 1,
    "appsNotReached": 1,
    "rollbackGaps": 1,
    "oldCopiesKept": 1
  },
  "installFailures": [
    { "appName": "Example Browser", "intuneAppId": "11111111-1111-4111-8111-111111111111", "failed": 4 }
  ],
  "unreached": [
    { "appName": "Example Viewer", "intuneAppId": "22222222-2222-4222-8222-222222222222", "deployedAt": "2026-10-20T14:00:00.000Z" }
  ],
  "rollbackGaps": [
    { "appName": "Example Browser", "intuneAppId": "11111111-1111-4111-8111-111111111111", "previousVersion": "120.0.1" }
  ],
  "oldCopiesKept": [
    { "appName": "Example Editor", "intuneAppId": "33333333-3333-4333-8333-333333333333", "version": "4.1.0", "newestAppId": "44444444-4444-4444-8444-444444444444" }
  ]
}
```

- `failedJobsLast7Days` and `stuckJobs` are left out if the job counts couldn't be read.
- Apps being retired are left out of `installFailures`, `unreached`, `rollbackGaps` and
  `oldCopiesKept`, as on Home.

### `GET /apps`

Win32 apps in Intune, sorted by name. The server reads up to 2,000 apps from Intune and keeps the
list for one minute.

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `search` | text, up to 100 characters | none | Matches part of the name, publisher or WinGet ID, ignoring case. |
| `limit` | 1 to 100 | 50 | Apps per page. |
| `cursor` | text | none | `nextCursor` from the previous page. |

```json
{
  "apps": [
    {
      "intuneAppId": "11111111-1111-4111-8111-111111111111",
      "displayName": "Example Browser",
      "version": "121.0.2",
      "publisher": "Example Software",
      "wingetId": "Example.Browser",
      "createdAt": "2026-09-01T12:00:00.000Z",
      "modifiedAt": "2026-10-30T08:15:00.000Z"
    }
  ],
  "total": 1,
  "nextCursor": null
}
```

- `wingetId` is set only for apps IntuneGet deployed, otherwise `null`.
- `total` counts the apps that match `search`.

### `GET /apps/{intuneAppId}`

One Win32 app. `{intuneAppId}` must be a GUID (`400` otherwise); unknown apps and apps that are
not Win32 get `404`.

```json
{
  "intuneAppId": "11111111-1111-4111-8111-111111111111",
  "displayName": "Example Browser",
  "version": "121.0.2",
  "publisher": "Example Software",
  "wingetId": "Example.Browser",
  "createdAt": "2026-09-01T12:00:00.000Z",
  "modifiedAt": "2026-10-30T08:15:00.000Z",
  "assignments": [
    { "groupLabel": "All users", "intent": "available" },
    { "groupLabel": "Pilot computers", "intent": "required" },
    { "groupLabel": "Excluded: Lab computers", "intent": "required" }
  ],
  "installCounts": { "installed": 212, "failed": 4, "pending": 3, "notApplicable": 0, "checkedAt": "2026-11-03T07:30:00.000Z" },
  "topErrors": [
    { "code": "0x80070643", "category": "The installer reported a failure", "count": 3 },
    { "code": "0x12345678", "category": null, "count": 1 }
  ],
  "rollbackAvailable": true,
  "retirementPhase": null,
  "pilotPhase": "testing"
}
```

- `assignments[].groupLabel`: the Entra group's name, `All users` or `All devices`. An exclusion
  starts with `Excluded: `. If the name can't be read, it is `Group name not available`.
- `assignments[].intent`: `required`, `available`, `uninstall` or `unknown`. Intune's
  "available without enrollment" is `available`.
- `installCounts` and `topErrors` appear only for the newest IntuneGet copy that the update check
  has read. `topErrors` has at most 10 codes. Codes HRM doesn't recognize as a number are grouped
  as `other`.
- `rollbackAvailable` appears only when the server has checked the previous installer.
- `retirementPhase`: `starting` or `uninstalling` while the app is being retired, otherwise `null`.
- `pilotPhase`: `starting`, `testing` or `promoting` while this copy is in an active pilot rollout,
  otherwise `null`.

### `GET /updates`

Newer versions found by the update check for apps IntuneGet deployed. Sorted by app name, at most
200.

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `includeDismissed` | `true` or `false` | `false` | Also list updates someone dismissed. |

```json
{
  "updates": [
    {
      "appName": "Example Browser",
      "wingetId": "Example.Browser",
      "intuneAppId": "11111111-1111-4111-8111-111111111111",
      "currentVersion": "121.0.2",
      "latestVersion": "122.0.0",
      "policy": "auto_update",
      "dismissed": false,
      "detectedAt": "2026-11-03T07:30:00.000Z"
    }
  ],
  "lastCheckedAt": "2026-11-03T07:30:00.000Z"
}
```

- Tenant-wide: rows saved for every staff member who deployed in this tenant are merged, newest
  first, so each app appears once.
- `currentVersion` already counts a copy deployed after the check, as App updates does.
- `policy`: `auto_update`, `notify`, `ignore`, `pin_version` or `null` (no policy). Apps set to
  Ignore or a pinned version are still listed, with their policy, so Claude can say why they are
  not updating.
- `lastCheckedAt`: when the last scheduled update check ran, from the status file.

### `GET /update-schedule`

When automatic updates and pilot starts may run. No parameters.

```json
{
  "supported": true,
  "enabled": true,
  "paused": false,
  "open": false,
  "window": { "days": ["Monday", "Wednesday"], "start": "22:00", "end": "06:00", "timeZone": "America/New_York" },
  "blackouts": [ { "start": "2026-12-24", "end": "2026-12-26", "label": "Holiday freeze" } ],
  "nextRunAt": "2026-11-04T03:00:00.000Z"
}
```

- `enabled: false` means any time is allowed; `window` then shows every day, `00:00` to `24:00`.
- An `end` before `start` runs past midnight and belongs to the day it started.
- Blackouts are whole Maryland dates, inclusive. Only current and future ones are listed, at most
  50. `label` is what staff typed (up to 60 characters).
- `nextRunAt`: the next time updates may start, or `null` when they may start now, are paused, or
  nothing opens in the next 62 days.
- Without SQLite the answer is `{ "supported": false, "paused": false }`.

### `GET /jobs`

Packaging and deployment jobs in the tenant, newest first. The server looks at the newest 500 jobs.

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `status` | one of the statuses below | none | Only jobs with this status. |
| `since` | ISO date or time | none | Only jobs created at or after this time. |
| `limit` | 1 to 100 | 25 | Jobs per page. |
| `cursor` | text | none | `nextCursor` from the previous page. |

Statuses: `queued`, `packaging`, `uploading`, `deployed`, `failed`, `cancelled`, `awaiting_qa`,
`qa_failed`, `duplicate_skipped`. Any other stored status is reported as `other`.

```json
{
  "jobs": [
    {
      "jobId": "55555555-5555-4555-8555-555555555555",
      "appName": "Example Browser",
      "wingetId": "Example.Browser",
      "version": "122.0.0",
      "status": "failed",
      "errorCode": "HASH_MISMATCH",
      "errorCategory": "installer",
      "intuneAppId": null,
      "automatic": true,
      "createdAt": "2026-11-03T08:00:00.000Z",
      "completedAt": null
    }
  ],
  "nextCursor": "1793692800000~55555555-5555-4555-8555-555555555555"
}
```

- `errorCode` is set only when the job didn't deploy and the stored code is an upper-case machine
  code; `errorCategory` only when it is a short lower-case category. Error and status messages are
  never sent.
- `automatic`: started by automatic updates rather than a person.
- `completedAt`: when it finished, or when it was cancelled.

### `GET /install-failures`

Apps whose newest copy has computers that failed to install it, most failures first. Apps being
retired are left out.

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `limit` | 1 to 100 | 25 | Apps to return. |

```json
{
  "apps": [
    {
      "appName": "Example Browser",
      "intuneAppId": "11111111-1111-4111-8111-111111111111",
      "failed": 4,
      "checkedAt": "2026-11-03T07:30:00.000Z",
      "topErrors": [ { "code": "0x80070643", "category": "The installer reported a failure", "count": 4 } ]
    }
  ],
  "total": 1,
  "generatedAt": "2026-11-03T12:00:00.000Z"
}
```

- `topErrors` has at most 5 codes per app, built as in `/apps/{intuneAppId}`.
- `total` counts every failing app, even past `limit`.

### `GET /pilots`

Pilot rollouts, active ones first, at most 100. No parameters.

```json
{
  "pilots": [
    {
      "pilotId": "66666666-6666-4666-8666-666666666666",
      "appName": "Example Browser",
      "wingetId": "Example.Browser",
      "phase": "testing",
      "fromVersion": "121.0.2",
      "toVersion": "122.0.0",
      "pilotGroupLabel": "Pilot computers",
      "previousAppId": "11111111-1111-4111-8111-111111111111",
      "newAppId": "77777777-7777-4777-8777-777777777777",
      "jobStatus": "deployed",
      "startedAt": "2026-11-01T15:00:00.000Z",
      "updatedAt": null
    }
  ]
}
```

- `phase`: `starting`, `testing`, `promoting` or `complete`.
- `updatedAt` is always `null`: the server does not record when a pilot last changed.
- Without SQLite the list is empty.

## Differences from the Worker's first contract

The Worker's `src/intuneget/contract.ts` was written before this API. These answers differ:

| Endpoint | Worker expects | Server sends | Why |
|---|---|---|---|
| `/attention` | `unreached[].notReached` (a count, required) | `unreached[].deployedAt` | An unreached app reaches no computers by definition, so there is no count to send. The Worker must swap the field or its schema check fails. |
| `/attention` | `counts` with any keys | the six keys above | Fixed names so they don't change between builds. |
| `/status` | `health` can be `down` | `ok`, `degraded` or `unknown` | If the server answers, the app is up. The Worker reports "down" itself when the request fails. |
| `/apps/{id}` | exclusions as plain groups | label starts with `Excluded: ` | So an exclusion is never read as an included group. |
| `/pilots` | `updatedAt` | always `null` | Not recorded. |
| `/update-schedule` | `paused` required | without SQLite, `supported: false` and `paused: false` | HRM's server always runs SQLite; this only covers a future move. |
| all | extra fields | `statusFile`, `diskPercentUsed`, `newestAppId`, `previousVersion`, `checkedAt`, `detectedAt`, `errorCategory`, `automatic`, `total`, `pilotId`, `wingetId`, `previousAppId`, `newAppId`, `jobStatus`, `enabled`, `supported` | Safe to drop. Add them to the Worker's schema to show them. |
| all | four settings on the server | five: the tenant too (`HRM_TENANT_ID`) | The Access service token carries no Intune tenant, and the server can serve more than one, so the tenant is set on purpose. |

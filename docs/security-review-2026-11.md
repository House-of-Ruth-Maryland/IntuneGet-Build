# November 2026 security, UX and performance review

A source review of the patched app (upstream v0.8.5 with HRM's patches) was written on
2026-11-05 against the old 38-patch stack and never merged. This page records what became of each
finding after it was checked against the 13-patch stack (deployed as `v0.8.5-hrm.27`) and ported.

- **Fixed before**: already fixed on `main` before this port.
- **Fixed now**: ported in this change, into the patch named.
- **Not ported**: left out on purpose; the reason is given.

| Finding | Result | Where and why |
|---|---|---|
| S1: signing in didn't mean permission to run Intune | Fixed before, partly fixed now | Fixed before by the IT admins group check (`HRM_ADMIN_GROUP_IDS`, `HRM_TENANT_ID`, patch 0011): every staff route checks the token's tenant and group membership, so a user from another tenant or outside the group can't reach any route or register a webhook. Fixed now in 0011: sign-in tokens must be unexpired and issued to IntuneGet's own sign-in app (`azp`/`appid` matches `AZURE_CLIENT_ID`, the same value the browser signs in with); the managed identity refuses any tenant other than `HRM_TENANT_ID` (or `MCP_TENANT_ID`) when one is set; Graph and token requests have deadlines; the token cache and Authorization header are bounded. Not ported: the review's operator list (`HRM_OPERATOR_IDS`), replaced by the group check, and its delivery filter for webhooks of removed owners (see below). |
| S1 (webhooks of removed staff) | Not ported | The server can only ask Microsoft about group membership with the user's own sign-in token, so it can't tell when a webhook's owner leaves the IT admins group without a new Graph application permission. Webhooks belong to the person who added them, so before removing someone from the group, have them delete theirs (CLAUDE.md, "Access to the app"). Deployment results already go only to webhooks on this one-tenant server. |
| S2: installer downloads accepted private IPv4 written in hex IPv6 | Fixed now (0004) | One shared public-address check (`lib/public-address.ts`) for installer downloads and webhooks. Hex and expanded IPv4-mapped IPv6, NAT64, 6to4, documentation and other reserved ranges are refused. The webhook guard already handled hex-mapped addresses (old patch 0024); installer downloads didn't. |
| S3: webhook DNS checked once, then resolved again to connect | Fixed now (0004) | Each delivery resolves once, checks every answer, and connects to that address while keeping the original name for TLS. No shared connection pool, no redirects, at most 8 KB of reply. |
| S4: Retire app could delete while uninstalls had failed | Fixed now (0010, 0009) | Ready to delete only with a complete report, no installed, pending, failed or unknown computers, and at least one Not installed (a copy with no Uninstall groups needs none). Anything else needs Delete without confirmation from Intune. Malformed, truncated or changing Intune reports are refused, and an unreadable report blocks deletion even with that box. |
| S5: a lost reply could leave a retirement stuck in "starting" | Fixed now (0010) | A timeout, network error or Intune server error during a group change keeps the hold. After a minute, Check retirement state reads the live groups: Uninstall groups continue the retirement, the saved groups drop it, anything else asks staff to set one in Intune. A cancel that reached Intune after its reply was lost can be repeated. |
| S6: monitoring read only the newest 2,000 history rows | Fixed now (0003, 0009, 0011) | The database returns the newest copy of every app (`currentDeployments`). Install results, Home's apps that reach no devices and Check installs now use it. Old install records are removed only after that complete list. The MCP read API's app-to-WinGet lookup still reads recent history only; it labels apps and changes nothing. |
| S7: production dependency advisories | Fixed now (0001) | A fresh `npm audit --omit=dev` found 4 app entries (2 high: `@azure/identity` and its nested `@azure/msal-node`; 2 moderate: `fflate` in three-stdlib, `baseline-browser-mapping`) and 2 high packager entries. `@azure/identity` 4.14.1 in both, packager `@azure/msal-node` 7, and overrides for `fflate` and `baseline-browser-mapping`. Both audits now report 0. |
| S8: builds didn't depend on tests | Fixed before, partly fixed now | Fixed before: every code PR runs Patched app regression checks (type checks for app and packager, Help, every test). Fixed now: that workflow also fails on production audit findings (moderate and above), and the image build first confirms the merged PR's "Patched app checks passed" succeeded, without running the suite again. Not ported: the review's separate `checks.yml`, which duplicated today's suite. |
| U1: Inventory details panel wasn't a real modal | Fixed now (0009) | The slide panel and bottom sheet use the dialog primitives: focus moves in, stays in and returns; Escape closes only the top dialog; the panel always has a name. |
| U2: long reviews could push buttons off screen | Fixed now (0008) | Centered dialogs and confirmations are limited to the screen height and scroll inside. |
| U3: other screens stayed stale after Retire app or Go back | Fixed now (0010) | Both refresh Inventory, app details, Home and every HRM view after a change. |
| U4: hidden panels and missing states | Fixed before, partly fixed now | Fixed before: Inventory's refresh button has a name (Reload from Intune). Fixed now: Retire app and Go back to previous version show loading and error states with Try again; Install results shows Not installed and Unknown. |
| Performance 1: Home counted every job in JavaScript | Fixed now (0003, 0011) | Counted in the database with an index (migration 25). |
| Performance 2: install reports read one app at a time with no limit | Fixed now (0009) | 3 reads at a time, a 2-minute limit per check, Retry-After for throttling, and a saved attempt time so the apps not reached are read first next time. Apps cut off by the limit are reported as deferred, not as failed reads, so the watchdog doesn't treat a large fleet as an Intune outage. |
| Performance 3: distinct current deployments | Fixed now | Same change as S6. |
| Performance 4: repeated live reads | Fixed now (0010) | People looking at the same retiring app share one Intune read for 15 seconds. Deleting always reads fresh counts. |
| Performance 5: front-end bundle | Not ported | The review asked for measurements first; no change was proposed. |

Also not ported: the review's extra user ID in the browser cache keys for Home, Install results,
Retire app and Go back (a small change for a one-tenant server that wasn't part of any finding), and
its formatting-only rewrites of files it touched.

Before deploying the image with these changes, check on the VM that `AZURE_CLIENT_ID` is the sign-in
app's client ID (it is set from `NEXT_PUBLIC_AZURE_AD_CLIENT_ID` in `docker-compose.yml`, and the
browser signs in with it) and that `HRM_TENANT_ID` (or `MCP_TENANT_ID`) is the Intune tenant.

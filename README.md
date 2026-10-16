# IntuneGet-Build

Builds HRM's IntuneGet container image: upstream
[ugurkocde/IntuneGet](https://github.com/ugurkocde/IntuneGet) at a release tag,
plus the small patches in `patches/`. Published as
`ghcr.io/house-of-ruth-maryland/intuneget:<tag>-hrm.<rev>`.

Build settings mirror upstream's release workflow (pinned actions, provenance, SBOM).

## Patches

| Patch | Why | Drop when |
|---|---|---|
| `0001-qa-gate-skip-without-supabase.patch` | In SQLite (no Supabase) mode the QA gate calls Supabase unconditionally, so GitHub-mode packaging can't start. | Upstream guards `enforceQaGate` for self-hosted installs. |
| `0002-tenant-view-without-supabase.patch` | Deployments → "All in tenant" (`GET /api/package?scope=tenant`) calls Supabase unconditionally, so the team view fails in SQLite mode. | Upstream guards the tenant-scope branch. |

## Build

Actions → "Build patched IntuneGet image" → Run workflow (choose the upstream tag).

## Retire

When upstream fixes the issue, switch the server back to `ghcr.io/ugurkocde/intuneget:<tag>`
and archive this repo.

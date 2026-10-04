# Phase 16 — Project `plume.yml` v2 (MVP)

## Objective

Move the project-root `plume.yml` beyond the phase-4 baseline so **mode**, **PHP version**, and (narrow MVP) **service enable** data are read from a single source and reflected in CLI behavior. Conflict rules with the central site registry (`~/.config/plume/sites`) must be documented.

## Status

- `done` (2026-07-29)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- Gate: D-117, D-118
- Source backlog: [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md) (D-089)
- Config draft: [03-config-yaml-draft.md](../03-config-yaml-draft.md)
- **Out of scope (separate phase):** docker-lite unfreeze — see [future-roadmap.md](../future-roadmap.md)

## MVP Scope (recommended)

- [x] Schema v2 draft: `project.mode`, `project.php_version` (and `project.type` if needed)
- [x] Loader: read `plume.yml` from project root; backward compatible with existing mode resolution ([site_mode_resolution_smoke.sh](../../tests/site_mode_resolution_smoke.sh))
- [x] Merge/precedence rule doc: project `plume.yml` vs user `services.yml` / `.env` (which field wins where)
- [x] At least one CLI path uses the MVP (e.g. `mode path` / `project` subcommand or php_version hint inside `site add`)
- [x] Hermetic smoke: temporary project directory + minimal `plume.yml`; no real `~/.config/plume`

## Stretch (within phase or 16b)

- [ ] `services.enabled[]` or env override map
- [ ] `sites[]` ↔ registry one-way sync or `plume sync` design note + D-xxx

## Test Checklist

- [x] `tests/phase16_plume_yml_v2_smoke.sh` (or expansion of existing site mode smoke)
- [x] `./tests/run_smoke_suite.sh --release` green (once the new step is added to release-readiness + runner)

## Documentation Checklist

- [x] [03-config-yaml-draft.md](../03-config-yaml-draft.md) — v2 fields marked
- [x] `docs/operations/` — project manifest usage (e.g. project config runbook)
- [x] New/changed commands → `docs/commands/`
- [x] `docs/contracts/` — `project config show` key=value (outside JSON critical list; see cli-output-contract.md)
- [x] Decision log: **D-117+** (schema, merge order, MVP limits)

## Gate Checklist (Mandatory)

- [x] MVP scope complete
- [x] Tests pass (`--release` / `--ci`)
- [x] Decision log updated
- [x] Tracker row `done` + completion date
- [x] [10-herd-parity-and-beyond.md](../10-herd-parity-and-beyond.md) — update `plume.yml` note (Phase 4 impact)

## Reference code

- `lib/common/plume_yml.sh` — MVP loader
- `lib/commands/site.sh` — mode/php hint integration
- `lib/commands/project.sh` — `project config show`
- `tests/site_mode_resolution_smoke.sh` — mode resolution smoke
- `tests/phase16_plume_yml_v2_smoke.sh` — hermetic v2 smoke

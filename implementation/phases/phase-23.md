# Phase 23 — Supervisor doctor, upgrade (--force), interactive program conf

## Objective

System-primary native supervisor (brew/systemd), `doctor supervisor`, first `--force` gated upgrade (package + config migration), template-based interactive program conf add.

## Status

- `done` (2026-08-30)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-149 (supersedes D-147 runtime partially)

## MVP Scope

- [x] `lib/services/native_supervisor.sh` — OS paths, registry, templates, upgrade, program add
- [x] `doctor supervisor` — PASS/WARN/FAIL + REMEDIATION + `--strict`
- [x] `services supervisor upgrade --force --yes [--dry-run]`
- [x] `services supervisor program add [--template=generic|horizon]`
- [x] `host.env` supervisor_* cache
- [x] Horizon refactor to system conf drop-in
- [x] Smoke: `phase23_supervisor_doctor_smoke.sh`; phase22 updated
- [x] D-150 per-site Horizon (`plume-horizon-<site-id>`, `site --horizon`, `phase24_per_site_horizon_smoke.sh`)

## Gate Checklist

- [x] MVP scope complete
- [x] Decision log D-149
- [x] `docs/commands/doctor-supervisor.md`, `docs/commands/services-supervisor.md`
- [x] OS matrix + services-horizon update
- [x] Tracker row

## Reference

- [services-supervisor.md](../../docs/commands/services-supervisor.md)
- [doctor-supervisor.md](../../docs/commands/doctor-supervisor.md)

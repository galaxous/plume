# Backlog: plume.yml v2 and Docker-Lite Unfreeze

Decision record: [05-decision-log.md](../05-decision-log.md) (D-089).

## plume.yml v2 (MVP — Phase 16 closed)

Existing baseline expanded (D-117): `project.mode`, `project.php_version`, `project.type`; loader + `project config show`.

Still backlog (stretch / 16b):

- `services.enabled[]` or env override map
- `sites[]` sync with registry (one-way or bidirectional `plume sync`)

## Docker-lite unfreeze (deferred)

- `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true` default discussion
- Image/template slimming
- Prod-lite single-compose ergonomics

## Trigger

- **plume.yml v2 MVP:** [phase-16.md](./phase-16.md) (`done`, 2026-07-29)
- **Docker-lite unfreeze:** no separate phase yet — see [future-roadmap.md](../future-roadmap.md) (Phase 17 candidate)

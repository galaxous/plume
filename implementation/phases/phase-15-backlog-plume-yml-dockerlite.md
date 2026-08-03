# Backlog: plume.yml v2 and Docker-Lite Unfreeze

Karar kaydi: [05-decision-log.md](../05-decision-log.md) (D-089).

## plume.yml v2 (MVP — Faz 16 kapandi)

Mevcut baseline genisletildi (D-117): `project.mode`, `project.php_version`, `project.type`; loader + `project config show`.

Hâlâ backlog (stretch / 16b):

- `services.enabled[]` veya env override map
- `sites[]` registry ile sync (tek yon veya `plume sync` cift yon)

## Docker-lite unfreeze (deferred)

- `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true` default tartismasi
- Image/template slimming
- Prod-lite single-compose ergonomisi

## Trigger

- **plume.yml v2 MVP:** [phase-16.md](./phase-16.md) (`done`, 2026-07-29)
- **Docker-lite unfreeze:** henuz ayri faz yok — bkz. [future-roadmap.md](../future-roadmap.md) (Phase 17 adayi)

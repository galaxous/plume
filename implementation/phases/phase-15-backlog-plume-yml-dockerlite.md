# Backlog: plume.yml v2 and Docker-Lite Unfreeze

Karar kaydi: [05-decision-log.md](../05-decision-log.md) (D-089).

## plume.yml v2 (deferred)

Mevcut baseline (phase 4): project-local `mode` cozumlemesi.

Planlanan genis schema:

- `project.mode`, `project.php_version`
- `services.enabled[]` veya env override map
- `sites[]` registry ile sync (tek yon veya `plume sync` cift yon)

## Docker-lite unfreeze (deferred)

- `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true` default tartismasi
- Image/template slimming
- Prod-lite single-compose ergonomisi

## Trigger

Bu backlog maddeleri Phase 15+ acilisinda ayri faz checklist ile baslatilir.

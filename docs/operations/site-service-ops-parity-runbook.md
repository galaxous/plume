# Site/Service Ops Parity Runbook

This runbook summarizes the steps for operating with the same command surface in `native`, `docker-lite`, and `laradock-bridge` modes.

## 1. Mode Selection

```bash
plumectl mode current
plumectl mode use native
plumectl mode use docker-lite
plumectl mode use laradock-bridge
```

## 2. Site Lifecycle (Same Command Surface)

```bash
plumectl site add --path=/abs/project --domain=app.test --server=nginx --publish
plumectl site update <site-id> --domain=app.test,www.app.test --publish
plumectl site publish <site-id> --reload
plumectl site check <site-id>
plumectl site remove <site-id>
plumectl site modes
```

Dry-run:

```bash
plumectl site add --path=/abs/project --domain=app.test --server=nginx --dry-run
plumectl site publish <site-id> --dry-run
plumectl site remove <site-id> --dry-run
```

## 3. Service Ops (Same Command Surface)

```bash
plumectl services supported --mode=native
plumectl services supported --mode=docker-lite
plumectl services supported --mode=laradock-bridge

plumectl services status --mode=native
plumectl services up --mode=native php
plumectl services down --mode=native php
```

## 4. Docker-Lite Compose Rule

- If `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true`, a compose file is required.
- Sources:
  - docker-lite workspace path registered via `mode path`
  - or `docker-compose.yml` / `compose.yml` in the working directory

## 5. Laradock Strict Rule

- If `PLUME_LARADOCK_STRICT=true`, these checks fail-fast before publish/reload:
  - whether `PLUME_LARADOCK_PATH` exists
  - whether the compose file exists (`PLUME_LARADOCK_COMPOSE_FILE` or `<path>/docker-compose.yml`)
  - whether the target container exists and is running

## 6. Reload Semantics

- `site publish --reload` attempts reload for the target server (`nginx|apache2|caddy`).
- If `PLUME_SITE_RELOAD_REQUIRED=true`, reload failure fails the command (`exit 2`).

## 7. Hosts Sync Semantics

- If `PLUME_SITE_HOSTS_SYNC=true`, the hosts entry is updated.
- If `PLUME_SITE_HOSTS_REQUIRED=true`, publish/update fails when hosts write fails.

## 8. Mode Visibility

- `plumectl site modes` lists which mode each site is registered in.
- This view is used for drift checks after a mode change.
- When a site is moved with `site update --mode=<mode>`, snippet/cache artefacts from the old mode are cleaned up.

## 9. Rollback Semantics

- If publish fails during `site update --publish`, the record is rolled back.
- Dry-run steps do not change files/registry.

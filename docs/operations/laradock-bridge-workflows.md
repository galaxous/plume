# Laradock Bridge Workflows

This runbook defines a safe, repeatable operations flow in `laradock-bridge` mode.

## 1. Bootstrap

```bash
plumectl mode use laradock-bridge
plumectl mode path set laradock-bridge /abs/laradock --force
plumectl services laradock check
```

Expected:

- path/compose/.env strict validation passes
- `APP_CODE_PATH_CONTAINER=/var/www` is verified
- the supported service map is discovered from compose

## 2. Desired Service Set

```bash
plumectl services config reset
plumectl services config add @core
plumectl services config add redis
plumectl services config show
```

Rules:

- `up/down all` only runs over the desired/resolved set.
- Compose services outside desired are not affected by default.

## 3. Lifecycle

```bash
plumectl services up all
plumectl services status --running
plumectl services health --running
plumectl services down all
```

Safe-order:

- `up all`: `db -> php -> queue -> web -> others`
- `down all`: `web -> queue -> php -> db -> others`

Failure rollback:

- If a start error happens during `up all`, services started earlier in that command are stopped in reverse order (rollback).

## 4. State Sync

```bash
plumectl sync state --mode=laradock-bridge
```

Notes:

- source-of-truth is the live compose/container state
- runtime + port state env files and the SQLite cache are updated
- multi host ports are written to the snapshot (`workspace=2222,3000`, `nginx=80,443`)

## 5. Logs/Exec/Containers

```bash
plumectl services logs @web --running --tail=50
plumectl services logs workspace --watch
plumectl services exec workspace bash
plumectl services containers
```

Note:

- `logs --watch` = `--follow` alias
- `status/health --watch[=N]` prints periodic refresh + timestamp

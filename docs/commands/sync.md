# `sync` Commands

## Purpose

Keep live runtime state (especially docker-lite) in sync via state files + SQLite.

## Usage

```bash
./plume.sh sync state --mode=docker-lite
./plume.sh sync state --mode=docker-lite --path=/abs/project
./plume.sh sync state --mode=laradock-bridge
./plume.sh sync state --mode=laradock-bridge --path=/abs/laradock

./plume.sh sync cron install --mode=docker-lite
./plume.sh sync cron status
./plume.sh sync cron remove
./plume.sh sync cron run --mode=docker-lite
```

## Notes

- `sync state` in docker-lite reads live container state and updates `services_runtime_*.env`, `services_ports_*.env`, and `plume-state.db` tables.
- `sync state` in laradock-bridge requires an explicit Laradock context:
  - `--path=/abs/laradock`
  - or `mode path set laradock-bridge /abs/laradock`
- For laradock-bridge sync, source-of-truth is live `docker compose` state.
- Laradock-bridge sync port introspection behavior:
  - service ports may be written as multiple host ports, not only a single one (`workspace=2222,3000`, `nginx=80,443`)
  - for web services, the `web_https` key is also synchronized.
- `sync cron install` writes an hourly cron by default (`0 * * * *`).
- Schedule can be changed with `--schedule="15 * * * *"`.

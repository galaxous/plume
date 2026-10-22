# Native pgAdmin (PostgreSQL UI)

## Purpose

Laradock `pgadmin` parity: web UI for PostgreSQL in native mode. Python venv under Plume state + `pip install pgadmin4`, HTTP `127.0.0.1:5050`.

## Usage

```bash
# ~/.config/plume/.env
POSTGRES_ENABLED=true
PGADMIN_ENABLED=true
PGADMIN_PORT=5050
PGADMIN_DEFAULT_EMAIL=pgadmin4@pgadmin.org
PGADMIN_DEFAULT_PASSWORD=admin

plumectl services install postgres --mode=native
plumectl services install pgadmin --mode=native
plumectl services up postgres pgadmin --mode=native
# or with enabled filter:
plumectl services up @db --mode=native

open http://127.0.0.1:5050
# Login: PGADMIN_DEFAULT_EMAIL / PGADMIN_DEFAULT_PASSWORD
# Register server: Host=127.0.0.1 Port=5432 User/Password=POSTGRES_*
```

`postgres` must be enabled for `pgadmin` (dependency).

## Parameters

| Variable | Description | Default |
|----------|-------------|---------|
| `PGADMIN_ENABLED` / `PLUME_PGADMIN_ENABLED` | Service toggle | `false` |
| `PGADMIN_PORT` / `PLUME_PGADMIN_PORT` | HTTP port | `5050` |
| `PGADMIN_DEFAULT_EMAIL` | UI login email | `pgadmin4@pgadmin.org` |
| `PGADMIN_DEFAULT_PASSWORD` | UI login password | `admin` |
| `PLUME_PGADMIN_VERSION` | Manifest version label | `latest` |

State:

- `state/native/pgadmin/venv/` — Python venv + pgadmin4
- `state/native/pgadmin/data/` — pgAdmin DATA_DIR
- `state/native/pgadmin/venv/.../config_local.py` — port/DATA_DIR

## Output / exit-code

- `services url pgadmin`: `url=http://127.0.0.1:5050`
- `services credentials pgadmin`: `email=`, `password=`, `http_port=`, `db_host=`, `db_port=`, …
- `0`: success
- `2`: postgres disabled, python3 missing, or install/start error

## Examples

```bash
plumectl services credentials pgadmin --mode=native
plumectl services restart pgadmin --mode=native
plumectl services down pgadmin --mode=native
```

## Error scenarios

- **pgadmin requires postgres to be enabled**: set `POSTGRES_ENABLED=true` in `.env`.
- **python3 required**: no Python 3 on host; install or use docker-lite/laradock-bridge.
- **5050 connection refused**: `services up pgadmin` did not run or PID died; log: `logs/services/native/pgadmin.log`.
- **Failed to create /var/lib/pgadmin**: old install could not write `config_local.py`; `services install pgadmin` + `services restart pgadmin` (D-139).
- **running=false / health=stopped**: usually the config/path error above, or first pip install incomplete.

OS matrix: [native-stack-os-matrix.md](../operations/native-stack-os-matrix.md).

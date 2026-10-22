# `services url` / `services credentials`

## Purpose

HTTP URL and connection info for web UI and database services in native mode (adapter-friendly key=value).

## Usage

```bash
plumectl services url phpmyadmin --mode=native
plumectl services url pgadmin --mode=native
plumectl services url mongo_webui --mode=native
plumectl services url redis_webui --mode=native
plumectl services credentials postgres --mode=native
plumectl services credentials mariadb --mode=native
plumectl services credentials mailpit --mode=native
plumectl services credentials memcached --mode=native
```

## Parameters

- `--mode=native` (required; Phase 17 MVP native-only)
- `<service>`: for url `phpmyadmin`, `pgadmin`, `mongo_webui`, `redis_webui`, `rabbitmq`, `mailpit`; for credentials `postgres`, `mariadb`, `mysql`, `mongodb`, `redis`, `rabbitmq`, `memcached`, `mongo_webui`, `redis_webui`, `phpmyadmin`, `pgadmin`, `mailpit`

## Output / exit-code

- `services url`: `url=http://127.0.0.1:<port>`
- `services credentials`: `host=`, `port=`, `user=`, `password=`, `database=` lines (by service)
- `0`: success
- `2`: unsupported service/mode or no data

## Examples

```bash
plumectl services url redis_webui --mode=native
# url=http://127.0.0.1:8083

plumectl services credentials postgres --mode=native
```

## Error scenarios

- native-only command in docker-lite/laradock-bridge mode
- Service never installed (credentials empty before `services install`)

OS matrix: [native-stack-os-matrix.md](../operations/native-stack-os-matrix.md).

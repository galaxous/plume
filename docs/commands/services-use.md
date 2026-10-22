# `services use`

## Purpose

Select a single database engine in native mode (like enabling one Laradock compose service and disabling the other). XOR: `mariadb` | `mysql` | `postgres`. Matching UI: phpMyAdmin (mysql-family) or pgAdmin (postgres).

## Usage

```bash
plumectl services use mariadb --mode=native
plumectl services use mysql --mode=native
plumectl services use postgres --mode=native
```

Then:

```bash
plumectl services up @db --mode=native
# or
plumectl services up @core --mode=native
```

## Parameters

- `<engine>`: `mariadb` | `mysql` | `postgres`
- `--mode=native` (required)

Behavior:

- Selected engine `ENABLED=true`; other two engines `false`
- `mariadb`/`mysql`: `services.yml` `database.engine` is updated (if present)
- `mariadb`/`mysql`: `PHPMYADMIN_ENABLED=true`, `PGADMIN_ENABLED=false`
- `postgres`: `PGADMIN_ENABLED=true`, `PHPMYADMIN_ENABLED=false`
- Values are written into global `~/.config/plume/.env` (short + `PLUME_*` names)

## Output / exit-code

- `engine=<name>` and `enabled_*=true|false` lines
- `0`: success
- `2`: non-native mode or invalid engine

## Examples

```bash
plumectl services use mariadb --mode=native
plumectl services up mariadb phpmyadmin --mode=native
plumectl services credentials mariadb --mode=native
```

## Error scenarios

- `services use mysql` conflicts with the mariadb formula on native brew; first `services down mariadb`
- phpMyAdmin does not work with `postgres` (D-127); `use postgres` disables phpmyadmin

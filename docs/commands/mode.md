# `mode` Commands

## Purpose

Change and validate the working mode.

## Usage

```bash
./plume.sh mode use native
./plume.sh mode use native --force --yes --down-running
./plume.sh mode use docker-lite
./plume.sh mode use laradock-bridge
./plume.sh mode current
./plume.sh mode path set /abs/project
./plume.sh mode path get
./plume.sh mode path clear
./plume.sh mode path set docker-lite /abs/project
./plume.sh mode path get docker-lite
./plume.sh mode path list
./plume.sh mode path clear docker-lite
```

## Parameters

- `use <mode> [--force] [--down-running]`
- `current`
- `path set [docker-lite|laradock-bridge] <path> [--force]`
- `path get [docker-lite|laradock-bridge]`
- `path clear [docker-lite|laradock-bridge]`
- `path list`

Note:

- If mode is omitted in `path` commands, the active mode (`mode current`) is used.

Priority order (deterministic):

- `mode`: `--mode` > global state saved by `mode use` > `native`
- docker-lite compose/path: `--path` > `mode path` > workspace remembered compose > current working directory compose
- laradock-bridge path: `--path` > `mode path`
- laradock-bridge compose: `PLUME_LARADOCK_COMPOSE_FILE` > `<mode-path>/docker-compose.yml|compose.yml`
- The `.env` file does not override `mode/path` values.

Laradock safety rule:

- `laradock-bridge` runtime commands do not guess the path.
- If `mode path set laradock-bridge <path>` was not done and `--path` was not passed, the command fails.
- This way plume knows deterministically which Laradock directory it will touch.

Lock behavior:

- After install/service start, the global context lock becomes active.
- If the lock is stale (no live workload), it is cleared automatically.
- While the lock is active, `mode use` and `mode path set/clear` do not change state without `--force`.
- If containers are running on the active `docker-lite` path, `mode/path` changes are blocked even with `--force`.
- In that case run `./plume.sh services workspace down --mode=docker-lite` first.
- Switching to `mode use native` is blocked while active `laradock-bridge` containers exist.
  - For automatic shutdown:
    - `./plume.sh mode use native --force --yes --down-running`
  - Manual shutdown alternative:
    - `cd <laradock-path> && docker compose down`
- During `docker-lite` path change (`mode path set ... --force`):
  - if containers are running on the old path, the change is blocked,
  - if the new path has no compose file, the command warns (`services workspace init` is suggested).

## Output / Exit Codes

- `0`: mode change succeeded
- `2`: invalid mode

## Examples

```bash
./plume.sh mode use native
./plume.sh mode current
```

## Error scenarios

- Invalid mode value
- Attempt to switch to a mode whose prereqs are not met
- `mode path set` with an invalid or missing path

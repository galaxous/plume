# `env` Commands

## Purpose

Manage Plume's system-level global env file.

## Usage

```bash
plumectl env where
plumectl env init
plumectl env init --force
plumectl env init --from=/abs/path/to/.env.example
plumectl env set PLUME_REDIS_PASSWORD=mysecret
```

## Parameters

- `where`
  - shows global env, global example, and built-in example file paths.
- `init`
  - initializes the global env file.
  - default source order:
    - `~/.config/plume/.env.example`
    - plume built-in: `templates/native-core.env.example`
    - `.env.example` in the working directory
  - preset sources:
    - local: `templates/native-local.env.example` (`PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=target`)
    - prod: `templates/native-prod.env.example` (`PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=target`)
  - custom source via `--from=...`.
  - `--force` overwrites the existing global env.
- `set KEY=VALUE`
  - updates or adds a `PLUME_*` key in `~/.config/plume/.env`.
  - for stack service keys, a restart suggestion is written for affected services.

## Output / Exit Codes

- `0`: success
- `2`: validation error (example file missing, invalid option, non-`PLUME_*` key)

## Examples

```bash
plumectl env where
plumectl env init
plumectl env init --force
plumectl env init --from=/path/to/plume/templates/native-local.env.example --force
plumectl env set PLUME_MONGODB_PASSWORD=example
plumectl services restart mongodb --mode=native
```

Stack service shortcut: [services-env.md](services-env.md).

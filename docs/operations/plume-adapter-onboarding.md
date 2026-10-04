# Plume Adapter Onboarding (Baseline)

This document defines the starting integration contract between a future `larasite-adapter`/`plume-adapter` package and the Plume CLI.

## 1) Adapter Design Principle

- The adapter runs system commands through `./plume.sh ...`, not directly.
- For parse work, prefer commands that support `--json`.
- On critical commands, the `--yes` requirement must be explicit on the adapter side.

## 2) Minimum Command Map

- Mode/context:
  - `./plume.sh mode current`
  - `./plume.sh mode context`
  - `./plume.sh mode use native --force --yes --down-running` (laradock-bridge transition safety)
  - `./plume.sh mode path get <mode>`
- Site lifecycle:
  - `./plume.sh site list --json`
  - `./plume.sh site check <id> --json`
  - `./plume.sh site add ...`
  - `./plume.sh site update ...`
  - `./plume.sh site remove <id>`
- Service/ops:
  - `./plume.sh services status --json`
  - `./plume.sh status --json`
  - `./plume.sh health --json`
  - `./plume.sh monitor summary --json`

## 3) Exit Code Contract

- `0`: success
- `1`: runtime/internal error
- `2`: validation/prereq/user-correctable error

On the adapter side, `2` codes should surface as a user correction flow rather than an exception.

## 4) Critical Command Guard

The following commands may be blocked without `--yes`:

- `mode use --force`
- `mode path set|clear --force`
- `services update`
- `services workspace reinit`
- `deploy rollback|failback` (except dry-run)
- `backup restore`

At the adapter UI/API level, "confirm" behavior should map to these commands.

## 5) State & Audit Sources

- State DB:
  - `~/.config/plume/state/plume-state.db` (or `PLUME_STATE_DIR`)
- Runtime events:
  - `./plume.sh monitor events --limit=100`

The adapter can filter `critical.*`, `deploy.*`, `security.*`, and `ops.*` event names in the event stream.

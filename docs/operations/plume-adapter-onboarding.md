# Plume Adapter Onboarding (Baseline)

This document defines the starting integration contract between a future `larasite-adapter`/`plume-adapter` package and the Plume CLI.

## 1) Adapter Design Principle

- The adapter runs system commands through `plumectl ...`, not directly.
- For parse work, prefer commands that support `--json`.
- On critical commands, the `--yes` requirement must be explicit on the adapter side.

## 2) Minimum Command Map

- Mode/context:
  - `plumectl mode current`
  - `plumectl mode context`
  - `plumectl mode use native --force --yes --down-running` (laradock-bridge transition safety)
  - `plumectl mode path get <mode>`
- Site lifecycle:
  - `plumectl site list --json`
  - `plumectl site check <id> --json`
  - `plumectl site add ...`
  - `plumectl site update ...`
  - `plumectl site remove <id>`
- Service/ops:
  - `plumectl services status --json`
  - `plumectl status --json`
  - `plumectl health --json`
  - `plumectl monitor summary --json`

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
  - `plumectl monitor events --limit=100`

The adapter can filter `critical.*`, `deploy.*`, `security.*`, and `ops.*` event names in the event stream.

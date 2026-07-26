# Phase 13 - Deploy Apply + Operate Journey

## Objective

`deploy apply` ile backup/health/reconcile/monitor zincirini tamamlamak.

## Status

- `done` (started: 2026-07-25, completed: 2026-07-25)

## Scope Checklist

- [x] `deploy apply` with `--dry-run`, `--skip-backup`, `--skip-health`, `--skip-reconcile`
- [x] Critical `--yes` guard + audit events

## Test Checklist

- [x] `tests/phase13_deploy_apply_smoke.sh`

## Documentation Checklist

- [x] `docs/commands/deploy.md`
- [x] `docs/operations/laravel-project-lifecycle.md`
- [x] Decision log D-087

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated

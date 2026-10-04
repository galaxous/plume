# Phase 06 - Native Service Orchestration

## Objective

- Native service install/manage/update with defaults, toggles, versions, and Laravel runtime services.

## Scope Checklist

- [x] Default true core services: `php`, `composer`, `mariadb`, `nginx`
- [x] Extra services default false + enable-on-update reconcile
- [x] Version pinning and custom versions (especially PHP)
- [x] PHP multi-version + default alias management
- [x] Horizon + Supervisor integration

## Implementation Checklist

- [x] Native adapters for supported services
- [x] Port intelligence and fallback allocation
- [x] Start/stop/status/logs/health command paths
- [x] Non-root runtime permissions verified
- [x] Version-aware status/supported output
- [x] Service dependency validation (horizon -> supervisor)
- [x] Services state file includes enabled+version metadata

## Test Checklist

- [x] Service toggle reconcile tests
- [x] Version switch/alias tests
- [x] Horizon supervisor lifecycle tests
- [x] Native E2E flow on macOS/Linux

## Documentation Checklist

- [x] `docs/commands/services.md`
- [x] `docs/commands/php.md`
- [x] `docs/operations/service-support-matrix.md`
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-03-07
- Owner: @team
- Related PR/Commit: phase-06-native-orchestration-baseline
- Open risks:
  - Native mode adapters currently run on a deterministic state/log/port file model; systemd/service-manager integration will be expanded in a later iteration.
  - The port fallback algorithm is based on local socket scanning; a stricter reserved-port policy may be needed in production.
  - In Phase-07/08, runtime log-health semantics for docker-lite/laradock must be fully equalized with native.

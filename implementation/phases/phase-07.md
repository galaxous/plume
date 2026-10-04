# Phase 07 - Docker-Lite Mode

## Objective

- Stabilize the Docker-lite baseline at beta level and move remaining lightweight goals into the backlog.

## Status

- `beta-frozen` (2026-03-10)
- Note: active development focus moved to Phase-08 (laradock-bridge) and native parity deepening.

## Scope Checklist

- [x] Compose/workspace model
- [x] Site publish compatibility
- [x] Service health/status parity
- [x] Majority service support parity with native
- [x] Version behavior parity (image tags/php aliases)

## Implementation Checklist

- [x] Docker-lite adapters complete
- [x] Workspace lifecycle commands
- [x] Container health checks integrated
- [x] Runtime logs and status unified output

## Test Checklist

- [x] Compose up/down/status tests
- [x] Service enable/disable behavior tests
- [x] Version pin tests
- [x] Native vs docker-lite parity checks

## Documentation Checklist

- [x] Docker-lite command docs
- [x] Support matrix update
- [x] Mode-specific env contract updates
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete at beta level
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-03-10
- Owner: @team
- Related PR/Commit: phase-07-docker-lite-runtime-parity + phase-07-beta-freeze
- Open risks:
  - Lightweight single-roof local/prod deployment ergonomics are not at the targeted level; moved to backlog.
  - Compose/service mapping simplification and image size optimization deferred to a later docker-lite iteration.
  - Primary focus: single command-surface parity in laradock-bridge + native modes.

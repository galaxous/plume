# Phase 08 - Laradock Bridge Mode

## Objective

- Build a safe bridge/adapter layer that runs Plume commands on existing Laradock stacks under the same contract as native.

## Status

- `done` (started: 2026-03-10, completed: 2026-04-03)
- Priority: high (docker-lite beta-frozen; focus on native + laradock-bridge parity)

## Scope Checklist

- [x] Laradock discovery (strict + non-strict path/compose detection)
- [x] Bridge sync and state mapping (runtime/state DB parity)
- [x] Health/status checks on existing containers
- [x] Desired service-set config for Laradock lifecycle
- [x] Safe interoperability and no destructive defaults
- [x] Command equivalence with native (same command surface, different engine)

## Implementation Checklist

- [x] Bridge adapters complete
- [x] Port/state introspection
- [x] Compatibility checks before apply (`services laradock check`)
- [x] Failure rollback behavior
- [x] Native<->laradock-bridge adapter contract normalization

## Test Checklist

- [x] Existing Laradock project integration smoke (`phase8-laradock-bootstrap-smoke`)
- [x] Bridge sync tests
- [x] Health-check/report tests
- [x] Regression tests with native unaffected
- [x] Docker-lite beta smoke unchanged

## Documentation Checklist

- [x] Laradock bridge command docs
- [x] Ops docs for bridge workflows
- [x] Support matrix updates
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-04-03
- Owner:
- Related PR/Commit:
- Open risks:
  - Laradock compose naming variations can strain bridge mapping (phase9 hardening backlog).
  - Runtime source-of-truth drift (live docker vs state DB) is reduced by periodic `sync state`, but event-level audit was left to phase9.
  - The multi-team/multi-project fixture set for APP_CODE_PATH_HOST/APP_CODE_PATH_CONTAINER strict guards should be expanded in phase9.

## Next-Phase Risks (for Phase 09)

- Resource consumption (cpu/io) in long-lived terminal sessions for watch/stream commands should be monitored.
- Discovery scope should be expanded for compose override chains (`docker-compose.override.yml`, custom include) on production-like Laradock stacks.
- Rollback behavior exists at lifecycle level; config-level transactional rollback and the backup/restore runbook must be completed in phase9 scope.

## Herd Parity / Beyond Review

- Herd parity:
  - Site onboarding + webserver adapter + php runtime mapping (native/laradock-bridge) goal achieved.
  - Service lifecycle (`up/down/status/health/logs/exec/containers`) parity completed at command-surface level.
- Beyond Herd:
  - Desired service-set orchestration, safe-order lifecycle, failure rollback, mode-path strict guards, and state DB telemetry added.
  - Phase9 focus: observability/ops/runbook productionization.

## Active Delivery Slice

- First active delivery slice:
  - [phase-08a-laradock-bridge-runtime-parity](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-08a-laradock-bridge-runtime-parity.md)
- This slice is treated as the first closable piece of Phase-08.
- Focus:
  - `services up/down/status/health/logs/exec/containers --mode=laradock-bridge`
  - live docker compose state -> plume state DB normalization

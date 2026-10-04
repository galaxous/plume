# Phase 01 - Foundation & Repo Standards

## Objective

- Modular shell layout, naming policy, and phase-gate workflow baseline.

## Scope Checklist

- [x] `plumectl` entrypoint and modular `lib/` structure
- [x] Naming policy aligned to Plume/plumectl
- [x] Phase docs and gate rules created
- [x] Local wrapper usage (`./plume.sh`)

## Implementation Checklist

- [x] Core command wiring exists (`help`, `mode`, `services`)
- [x] Reconcile state file foundation added
- [x] `.env.example` shared contract baseline created
- [x] Phase 1 cleanup pass complete

## Test Checklist

- [x] `./plume.sh --help`
- [x] `./plume.sh mode current`
- [x] `./plume.sh services supported`
- [x] Phase 1 end-to-end checklist run captured

## Documentation Checklist

- [x] Naming docs updated
- [x] Env contract docs updated
- [x] Service support matrix initialized
- [x] Phase planning docs updated

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass (final pass)
- [x] Decision log updated (`implementation/05-decision-log.md`)
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-03-06
- Owner: @team
- Related PR/Commit: local workspace changes
- Open risks:
  - In Phase 2, the global flag standard (`--json`, `--quiet`, `--env-file`) must be brought online.
  - `services install/up/down` is currently a phase1 stub; real orchestration will be completed in Phase 6.

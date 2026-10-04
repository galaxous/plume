# Plume Implementation Context

This folder stores Plume's phased development plan and technical decision context.
Goals:

- Help a future AI or human contributor quickly understand "what, why, and in what order"
- Track the three-scenario architecture (native, docker-lite, laradock-bridge) from a single source
- Record decisions, risks, and remaining work at the end of each phase
- Keep the development process decomposable via modular shell import layout

## Files

- `phase-tracker.md`: master board tracking all phases on one screen
- `01-phased-plan.md`: Phase-based roadmap
- `02-architecture.md`: Target architecture and modules
- `03-config-yaml-draft.md`: Configuration (local + production) YAML contract draft
- `04-operations-observability.md`: Log, health-check, monitoring plan
- `05-decision-log.md`: Architecture decision log (ADR-lite)
- `06-prerequisites-matrix.md`: macOS/Linux core dependency check matrix
- `07-site-onboarding-and-obstacles.md`: site add UX, registry model, and risks
- `08-documentation-strategy.md`: full docs set and documentation requirements
- `09-answer-driven-constraints.md`: mandatory requirements clarified by user answers
- `10-herd-parity-and-beyond.md`: herd parity + beyond scope checklist
- `future-roadmap.md`: single-page todo summary (Phase 17+ candidates, open parity items)
- `11-status-2026-07-28.md`: current readiness (Phases 1–15 closed; Phase 7 beta-frozen)
- `11-status-2026-03-24.md`: historical readiness note
- `12-quality-gate-report-2026-04-03.md`: phase-10 baseline matrix quality gate report
- `phases/phase-XX.md`: per-phase implementation checklists
  - active sub-delivery note:
    - `phases/phase-08a-laradock-bridge-runtime-parity.md`

## Working Rules

For every new development:

1. Update the relevant phase row in `phase-tracker.md`
2. Mark related checklist items in `phases/phase-XX.md`
3. Add any new technical decision to `05-decision-log.md`
4. If the config contract changes, revise `03-config-yaml-draft.md`
5. Update related command/operations docs under `docs/`

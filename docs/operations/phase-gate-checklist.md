# Phase Gate Checklist

Mandatory checklist before a phase is closed:

1. Feature scope is complete
2. Tests were added and passed
3. Related files under `docs/commands/` were updated
4. `docs/contracts/` was updated if needed
5. `implementation/05-decision-log.md` was updated
6. Risks for the next phase were written down
7. E2E scenarios in phase scope (not smoke) passed
8. Checklist impacts in `implementation/10-herd-parity-and-beyond.md` were updated

Do not move to the next phase until the checklist is complete.

## Tracking Flow

1. Update `implementation/phase-tracker.md` for master status.
2. Update `implementation/phases/phase-XX.md` for phase details.
3. Before the phase is `done`, mark all 8 gate items in this file.

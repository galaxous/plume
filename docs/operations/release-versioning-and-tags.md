# Release Versioning and Tag Rules

Plume release policy for the Phase-10 baseline:

## Versioning

- SemVer is used: `MAJOR.MINOR.PATCH`
- `MAJOR`: CLI/contract breaking change
- `MINOR`: backward-compatible new command/feature
- `PATCH`: bug fix, test/doc corrections (no contract change)

## Tag Format

- Stable: `vX.Y.Z`
- Pre-release: `vX.Y.Z-rc.N`

## Branch and Release Flow

1. Phase checklist and quality gate report must be current.
2. `./tests/phase10_e2e_matrix_smoke.sh` must succeed.
3. A release/contract change entry must be written to the Decision log.
4. For a stable publish, tag `vX.Y.Z` is created.

## Contract Guardrail

- A contract change is not merged without updating `docs/contracts/cli-output-contract.md`.
- On contract-affecting changes, at least these tests are required:
  - `tests/phase8_adapter_contract_normalization_smoke.sh`
  - `tests/phase10_e2e_matrix_smoke.sh`

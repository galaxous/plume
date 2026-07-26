# Release Versioning and Tag Rules

Phase-10 baseline icin Plume release politikasi:

## Versioning

- SemVer kullanilir: `MAJOR.MINOR.PATCH`
- `MAJOR`: CLI/contract breaking degisiklik
- `MINOR`: geriye uyumlu yeni komut/ozellik
- `PATCH`: bugfix, test/dokuman duzeltmeleri (contract degisikligi yok)

## Tag Format

- Stable: `vX.Y.Z`
- Pre-release: `vX.Y.Z-rc.N`

## Branch and Release Flow

1. Phase checklist ve quality gate raporu guncel olmali.
2. `./tests/phase10_e2e_matrix_smoke.sh` basarili olmali.
3. Decision log'a release/contract degisiklik kaydi yazilmali.
4. Stable yayin icin `vX.Y.Z` tag atilir.

## Contract Guardrail

- `docs/contracts/cli-output-contract.md` guncellemesi olmadan contract degisimi merge edilmez.
- Contract etkileyen degisikliklerde en az su testler zorunlu:
  - `tests/phase8_adapter_contract_normalization_smoke.sh`
  - `tests/phase10_e2e_matrix_smoke.sh`

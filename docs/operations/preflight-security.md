# Preflight & Security Baseline

Bu dokuman Phase 3'teki OS/prereq fail-fast davranisini ozetler.

## Hedef

- Komut calismadan once cekirdek bagimliliklari dogrulamak
- Eksik bagimlilikta deterministik hata ve kurulum onerisi vermek
- Kurulum/guncelleme aksiyonlarinda root boundary uygulamak

## Prereq Akisi

1. `./plume.sh prereq check --profile=<name>`
2. Eksik komut varsa `exit 2`
3. Cikti icinde uygun package-manager install hint'i verilir (`brew/apt/dnf`)

JSON cikti:

```bash
./plume.sh --json prereq check --profile=base
```

## Root Boundary

Root/sudo zorunlu:

- `./plume.sh services install ...`
- `./plume.sh services update`

Non-root calisabilen runtime odakli komutlar:

- `./plume.sh services supported`
- `./plume.sh services status`
- `./plume.sh services up/down` (root gerektirmez; gercek host start/stop icin `PLUME_NATIVE_HOST_PROVISION=true` ve OS'e gore brew/sudo gerekebilir)

## macOS + Linux Test Stratejisi

- macOS native smoke:
  - `tests/phase3_prereq_smoke.sh`
- Linux matrix (Mac uzerinde Docker ile):
  - `tests/linux_prereq_matrix.sh`
  - Ubuntu (`apt`) + Fedora (`dnf`) container check

Tek komutla:

```bash
PLUME_RUN_LINUX_TESTS=1 tests/phase3_prereq_smoke.sh
```

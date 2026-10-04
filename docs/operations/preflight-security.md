# Preflight & Security Baseline

This document summarizes the OS/prereq fail-fast behavior in Phase 3.

## Goal

- Validate core dependencies before a command runs
- On missing dependencies, return a deterministic error and install suggestion
- Enforce the root boundary on install/update actions

## Prereq Flow

1. `./plume.sh prereq check --profile=<name>`
2. If a command is missing, `exit 2`
3. Output includes an appropriate package-manager install hint (`brew/apt/dnf`)

JSON output:

```bash
./plume.sh --json prereq check --profile=base
```

## Root Boundary

Root/sudo required:

- `./plume.sh services install ...`
- `./plume.sh services update`

Runtime-focused commands that can run as non-root:

- `./plume.sh services supported`
- `./plume.sh services status`
- `./plume.sh services up/down` (does not require root; real host start/stop may need `PLUME_NATIVE_HOST_PROVISION=true` and brew/sudo depending on OS)

## macOS + Linux Test Strategy

- macOS native smoke:
  - `tests/phase3_prereq_smoke.sh`
- Linux matrix (via Docker on Mac):
  - `tests/linux_prereq_matrix.sh`
  - Ubuntu (`apt`) + Fedora (`dnf`) container check

In one command:

```bash
PLUME_RUN_LINUX_TESTS=1 tests/phase3_prereq_smoke.sh
```

# Core Prerequisites Matrix

Goal: Standardize the core dependencies that must work before service packages.

## Rule

- If a core prereq is missing, the related command stops fail-fast.
- Output carries:
  - missing command/package
  - why it is required
  - OS-specific install suggestion

## OS-Based Package Manager

- macOS: `brew`
- Linux:
  - Debian/Ubuntu: `apt`
  - RHEL/Fedora: `dnf`
  - Others: `manual` (guidance provided; no automatic install)

## Prereq Profiles (Phase 3)

1. `base`
- Commands: `bash sed awk grep cut xargs tar gzip curl`
- Usage: minimum profile for all commands

2. `native-install`
- Commands: `sudo` + OS package manager (`brew/apt/dnf`)
- Usage: host service install steps

3. `git-ops`
- Commands: `git ssh`
- Usage: repo/remote operations

4. `docker-lite`
- Commands: `docker`
- Usage: docker-lite and laradock-bridge paths

5. `security-check`
- Commands:
  - macOS: `pfctl`
  - Linux baseline: `getenforce`
- Usage: initial firewall/OS security preflight check

6. `horizon-runtime`
- Commands: `supervisorctl php`
- Usage: Laravel Horizon process control

7. `laravel-bootstrap`
- Commands: `php composer`
- Usage: `project init` bootstrap steps

8. `frontend-build`
- Commands: `node npm`
- Usage: build/dev server flows

## CLI Behavior

- `./plume.sh prereq check --profile=<name>`
  - lists missing items
  - exit code: `2` if missing, otherwise `0`
- `./plume.sh prereq explain`
  - returns profile + rationale list
- `./plume.sh --json prereq check --profile=<name>`
  - returns machine-readable output

## Root Boundary (Phase 3)

- Install/update steps require root/sudo:
  - `./plume.sh services install ...`
  - `./plume.sh services update`
- Runtime-focused commands do not require root:
  - `services status`, `services supported`, `services up/down` (phase1/2 stub level)

## Linux Test Solution (On Mac)

- Local Linux verification is done via container:
  - `tests/linux_prereq_matrix.sh`
  - Prereq profiles run in Ubuntu (`apt`) and Fedora (`dnf`) containers
- Full Phase 3 smoke:
  - `tests/phase3_prereq_smoke.sh`
  - To include the Linux matrix: `PLUME_RUN_LINUX_TESTS=1 tests/phase3_prereq_smoke.sh`

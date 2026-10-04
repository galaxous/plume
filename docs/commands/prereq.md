# `prereq` Commands

## Purpose

Fail-fast check of core dependencies by profile.

## Usage

```bash
./plume.sh prereq check
./plume.sh prereq check --profile=base
./plume.sh prereq check --profile=native-install
./plume.sh prereq explain
./plume.sh --json prereq check --profile=git-ops
```

## Parameters

- `check`: profile-based prereq check
  - `--profile=base|native-install|git-ops|docker-lite|security-check|horizon-runtime|laravel-bootstrap|frontend-build`
- `explain`: list all profiles and their rationale

## Output / Exit Codes

- `0`: all required dependencies present
- `2`: missing dependency or invalid usage

## Examples

```bash
./plume.sh prereq check --profile=base
./plume.sh prereq check --profile=native-install
./plume.sh --json prereq check --profile=docker-lite
./plume.sh prereq explain
```

## Error scenarios

- Unknown profile
- Missing core command/package (including `brew/apt/dnf`)
- Invalid flag usage

## Notes

- On macOS, package manager checks use `brew`.
- On Linux, package manager checks use `apt` or `dnf`.
- Install commands such as service install/update require root/sudo.

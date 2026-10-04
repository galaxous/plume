# Phase 03 - OS Detection & Core Prereq Guard

## Objective

- macOS/Linux detection and fail-fast prerequisite enforcement.

## Scope Checklist

- [x] OS and package manager detection (`brew`, `apt`, `dnf`)
- [x] Core dependency checks before execution
- [x] Missing-core-package hard stop with install guidance
- [x] Security scope preflight checks (firewall/SELinux/AppArmor baseline)

## Implementation Checklist

- [x] `prereq check` command behavior complete
- [x] Core vs service dependency separation
- [x] Root-needed action guards
- [x] Consistent machine-readable output option

## Test Checklist

- [x] macOS path checks
- [x] Linux path checks
- [x] Missing dependency failure path tests
- [x] Permission boundary tests

## Documentation Checklist

- [x] `docs/commands/prereq.md`
- [x] `implementation/06-prerequisites-matrix.md`
- [x] Ops docs for preflight behavior
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-03-06
- Owner: @team
- Related PR/Commit: local workspace changes
- Open risks:
  - The `security-check` profile should be extended on Linux with AppArmor/firewalld/ufw signals.
  - In Phase 4, the site onboarding flow must be enforced at command level together with prereq profiles.

# Phase 02 - CLI Core & Router

## Objective

- Stable command router, global flags, and exit-code contract.

## Scope Checklist

- [x] Router with command families (`mode/site/services/prereq/status/project/deploy/backup`)
- [x] Global flags standard (`--help`, `--json`, `--yes`, `--env-file`)
- [x] CLI output contract alignment
- [x] Non-root runtime vs root install/update permission model enforcement

## Implementation Checklist

- [x] Command dispatch table completed
- [x] Validation and error classification implemented
- [x] Shared parser/utils stabilized
- [x] Backward compatibility aliases decided

## Test Checklist

- [x] Router unit tests
- [x] Exit-code behavior tests
- [x] Invalid-arg integration tests
- [x] Cross-shell invocation checks (zsh/bash)

## Documentation Checklist

- [x] `docs/commands/global.md`
- [x] Related command pages
- [x] `docs/contracts/cli-output-contract.md`
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
  - In Phase 3, prereq profiles (`brew/apt/dnf`) and the fail-fast matrix must be completed.
  - Command-level `--help` behavior and global/command flag precedence should be standardized in more detail.

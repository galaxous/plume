# Documentation Strategy (Full Set)

## Goal

A documentation set that explains every Plume command in detail, can be used as a server operations reference, and provides fast onboarding for the future `plume-adapter` package.

## Structure

- `docs/commands/`: Command-based usage
- `docs/contracts/`: Parseable output contracts
- `docs/operations/`: Runbooks and phase-gate checklists
- `docs/operations/naming-policy.md`: brand/cli/repo/package naming standard

## Required Command Doc Headings

1. Purpose
2. Usage
3. Parameters
4. Output / Exit Codes
5. Examples
6. Error Scenarios

## Update Rule

- When code changes, docs change too (same change set)
- When a new command is added, `docs/commands/<command>.md` is added at the same time
- When the output schema changes, `docs/contracts/cli-output-contract.md` is updated

## Adapter Readiness (Out of Scope but Planned)

- Commands produce deterministic output
- Exit code standardization
- Schema stability of `--json` mode

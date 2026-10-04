# `doctor workspace`

## Purpose

Diagnoses Composer / npm / node host binaries and Plume workspace CLI readiness (D-154 / Phase 27).

## Usage

```bash
plumectl doctor workspace
plumectl doctor workspace --strict
plumectl doctor workspace --mode=native
```

## Parameters

- `--mode=native|docker-lite|laradock-bridge`
- `--strict`: exit 2 when a critical FAIL is present

## Output / exit-code

- `0`: OVERALL OK (WARN allowed)
- `2`: `--strict` and critical FAIL

## Examples

```bash
plumectl doctor workspace
```

## Error scenarios

- `composer` / `npm` / `node` WARN — related binary or `PLUME_*_BIN`
- docker mode: workspace container path; compose init may be required

Related: [workspace.md](./workspace.md)

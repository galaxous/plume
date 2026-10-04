# `npm` Command

## Purpose

Runs npm in the project directory. Details: [workspace.md](./workspace.md) (D-154).

## Usage

```bash
plumectl npm install
plumectl npm run build
plumectl npm --path=/abs/app run dev
```

## Parameters

`--path=`, `--site=`, `--mode=` — see [workspace.md](./workspace.md).

## Output / exit-code

npm exit code; Plume error `2`.

## Examples

```bash
plumectl npm -v
plumectl npm ci
```

## Error scenarios

- `npm not found` — Node.js or `PLUME_NPM_BIN`
- Compose missing (docker mode) — workspace init

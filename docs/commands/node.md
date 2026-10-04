# `node` Command

## Purpose

Runs Node in the project directory. Details: [workspace.md](./workspace.md) (D-154).

## Usage

```bash
plumectl node -v
plumectl node --path=/abs/app script.js
```

## Parameters

`--path=`, `--site=`, `--mode=` — see [workspace.md](./workspace.md).

## Output / exit-code

node exit code; Plume error `2`.

## Examples

```bash
plumectl node -e 'console.log(1)'
```

## Error scenarios

- `node not found` — Node.js or `PLUME_NODE_BIN`

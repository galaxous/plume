# `version` Command

## Purpose

Shows the CLI version. Source: repo `VERSION` (D-155).

## Usage

```bash
plumectl version
plumectl --version
plumectl -v
plumectl --json version
```

## Parameters

None (global `--json` is supported).

## Output / exit-code

- Text: `plumectl <semver>`
- JSON: `{"ok":true,"command":"version","data":{"name":"plumectl","version":"<semver>"}}`
- Exit `0`

## Examples

```bash
plumectl version
```

## Error scenarios

- If `VERSION` is missing, `0.0.0-dev` is printed

Related: [release.md](../operations/release.md)

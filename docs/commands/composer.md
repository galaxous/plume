# `composer` Command

## Purpose

Runs Composer in the project directory (site PHP preferred). Details: [workspace.md](./workspace.md) (D-154).

## Usage

```bash
plumectl composer install
plumectl composer --path=/abs/app require laravel/horizon --no-interaction
plumectl composer --site=site-xxx update
```

## Parameters

`--path=`, `--site=`, `--mode=` — see [workspace.md](./workspace.md).

## Output / exit-code

Composer exit code; Plume error `2`.

## Examples

```bash
plumectl composer --version
plumectl composer install --no-dev
```

## Error scenarios

- `composer not found` — host Composer or `PLUME_COMPOSER_BIN`
- `could not resolve project path` — `--path=` / project root

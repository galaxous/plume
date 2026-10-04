# `project config` Command

## Purpose

Read Phase 16 MVP fields from the project-root `plume.yml` and print human-readable output (`project.mode`, `project.php_version`, `project.type`).

## Usage

```bash
plumectl project config show --path=/abs/project
```

## Parameters

- `--path=<abs_path>`: required; project directory (contains `plume.yml` or `PLUME_CONFIG_FILE` target)

## Output / exit-code

- Output: `key=value` lines (`manifest=`, `schema_version=`, `mode=`, `php_version=`, `project_type=` — empty fields omitted)
- `0`: successful read
- `2`: path/manifest missing, invalid `project.type`, or invalid mode

## Examples

```bash
./plume.sh project config show --path=/var/www/myapp
```

Example output:

```text
manifest=/var/www/myapp/plume.yml
schema_version=2
mode=docker-lite
php_version=8.2
project_type=laravel
```

## Error scenarios

- `--path` not given or directory missing
- `plume.yml` not found
- Invalid `project.type` or `mode` value

Merge rules: [docs/operations/project-plume-yml.md](../operations/project-plume-yml.md).

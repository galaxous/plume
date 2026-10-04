# Project-local `plume.yml` (Phase 16 MVP)

`plume.yml` at the project root reads a **narrow MVP** field set for site onboarding and CLI resolution. Full draft: [implementation/03-config-yaml-draft.md](../../implementation/03-config-yaml-draft.md). Decision: [implementation/05-decision-log.md](../../implementation/05-decision-log.md) (D-117).

## MVP fields

```yaml
version: 2          # optional; for documentation
project:
  mode: native      # native | docker-lite | laradock-bridge
  php_version: "8.3"
  type: laravel     # laravel | generic-php | static (optional)
mode: native        # phase-4 backward compatibility; project.mode takes precedence
```

Default file name is `plume.yml`; override: `PLUME_CONFIG_FILE` (relative to project root or absolute path).

## Merge / precedence rules

| Field | Project `plume.yml` | User `services.yml` | `~/.config/plume/.env` | CLI / registry |
|------|-------------------|--------------------------|-------------------------|----------------|
| `project.mode` | Resolution hint | — | `PLUME_MODE` (global) | `--mode` wins; registered site `mode` is authoritative for site operations |
| `project.php_version` | `site add` hint | — | `PLUME_PHP_*` installed version list | `--php` / `--php-version` wins |
| Service enable | Outside MVP (stretch) | Yes (D-103) | Yes (over the manifest) | `services` commands |
| Domain / path | Outside MVP | — | — | Site registry + `site add/update` |

There is **no** automatic two-way sync with the registry (`PLUME_SITE_REGISTRY_DIR` or `~/.config/plume/sites`); the manifest is a read/hint layer only.

## Commands

- `plumectl project config show --path=/abs/project` — prints loaded MVP fields.
- `plumectl site add` — if `--mode` is absent, manifest mode; if `--php` is absent, `project.php_version` (after validation).

## Smoke

Hermetic test: `tests/phase16_plume_yml_v2_smoke.sh` (temporary `HOME`, `PLUME_STATE_DIR`, `PLUME_SITE_REGISTRY_DIR`).

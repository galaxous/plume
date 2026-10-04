# `project` Command

## Purpose

The `plumectl project` family gathers Laravel project bootstrap and `.env` secret sync steps into one surface.

## Usage

```bash
plumectl project init --path=/abs/project
plumectl project config show --path=/abs/project
plumectl project init --path=/abs/project --migrate --seed --npm-install --npm-build
plumectl project init --path=/abs/project --dry-run
plumectl project env sync-secrets --path=/abs/project --keys=APP_KEY,DB_PASSWORD
```

## Parameters

- `--path=<abs_path>`: required project path
- `--dry-run`: print steps as a plan only; no file/command changes
- `--migrate`: `php artisan migrate --force`
- `--seed`: `php artisan db:seed --force` (also runs `--migrate` automatically)
- `--npm-install`: `npm install`
- `--npm-build`: `npm run build`
- `--npm-dev`: `npm run dev`
- `--skip-composer`: skip the `composer install` step
- `--skip-key-generate`: skip the `php artisan key:generate` step
- `--skip-storage-link`: skip the `php artisan storage:link` step
- `project env sync-secrets`:
  - `--path=<abs_path>`: required project path
  - `--keys=K1,K2`: optional key filter (all secret keys if omitted)
  - `--dry-run`: show planned `.env` changes without writing
  - `--create-env`: if `.env` is missing, create it from `.env.example`

## Behavior

1. If `composer.json` exists, `composer install`
2. If `.env` is missing, create `.env` from `.env.example`
3. If `artisan` exists:
   - `key:generate`
   - `storage:link`
   - optional `migrate` / `db:seed`
4. If `package.json` exists, optional npm steps
5. `project env sync-secrets` writes/updates keys from state `secrets.env` into the project `.env`
6. `project config show` reads project `plume.yml` MVP fields — details: [project-config.md](project-config.md)

## Subcommands

| Subcommand | Docs |
|------------|------|
| `init` | this file |
| `config show` | [project-config.md](project-config.md) |
| `env sync-secrets` | this file |

## Exit Codes

- `0`: success
- `2`: input/validation error or step command error

## Examples

```bash
plumectl project init --path=/var/www/myapp
plumectl project init --path=/var/www/myapp --migrate --seed
plumectl project init --path=/var/www/myapp --skip-composer --dry-run
plumectl project env sync-secrets --path=/var/www/myapp --keys=APP_KEY,DB_PASSWORD
```

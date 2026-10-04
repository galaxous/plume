# `composer` / `npm` / `node` (workspace)

## Purpose

Herd-like Composer and Node development surface: runs tools from the project root on the host (native) or inside the `workspace` container (docker-lite / laradock-bridge) (D-154 / Phase 27).

## Usage

```bash
plumectl composer install
plumectl composer --path=/var/www/app require laravel/horizon
plumectl composer --site=site-xxx update
plumectl npm install
plumectl npm run build
plumectl npm --path=/var/www/app run dev
plumectl node -v
plumectl composer --mode=docker-lite install
```

## Parameters

| Flag | Description |
|------|-------------|
| `--path=` | Project root (`composer.json` / `package.json` / `artisan`) |
| `--site=` | Registered site path (+ site `php_version` for composer) |
| `--mode=` | `native` (default: active mode) / `docker-lite` / `laradock-bridge` |
| `--` | Remaining args are tool flags (optional separator) |

Tool arguments after Plume flags go directly to `composer` / `npm` / `node`. With no args, a version flag (`-V` / `-v`) is used.

Note: plumectl global `--version` / `-v` shows Plume version; for tool version use `composer -V`, `npm -- -v`, `node -- -p process.version`, or `tool -- --version`.

## Behavior

### native

- Project path: `--path` → `--site` → cwd site match → cwd (`composer.json`/`package.json`/`artisan`) → mode path
- **npm:** error if cwd or mode path has neither `package.json` nor `artisan` (no ENOENT in an empty directory)
- **composer:** requires `composer.json` or `artisan`
- **node:** falls back to cwd when project markers are missing (one-liner / `-p`); not as strict as npm
- Composer: site/default PHP is prepended to `PATH` (`COMPOSER_PHP` when possible); `PLUME_COMPOSER_BIN` (default `composer`)
- npm/node: `PLUME_NPM_BIN` / `PLUME_NODE_BIN` (default `npm` / `node`)

### docker-lite / laradock-bridge

- Runs `composer|npm|node` via exec (`-T`) inside the `workspace` (composer alias) container
- Compose file requires mode path / workspace init

## Output / exit-code

- `0`: tool succeeded (or `--help`)
- `2`: path unresolved, binary missing, compose missing, unknown mode/flag
- Tool returns its own exit code (failed install, etc.)

## Examples

```bash
cd ~/Sites/tunnelion
plumectl composer install --no-interaction
plumectl npm ci
plumectl npm run build
```

## Error scenarios

- `could not resolve project path` — run with `--path=` / `--site=` / from project root (`npm` needs `package.json` or `artisan`)
- `composer not found` — host Composer or `PLUME_COMPOSER_BIN`
- `npm not found` / `node not found` — Node.js or `PLUME_NPM_BIN` / `PLUME_NODE_BIN`
- `compose file not found` — docker mode: `services workspace init` / mode path

Related: [project.md](./project.md) (`project init` bootstrap), [php.md](./php.md) (PHP matrix).

# `php` Commands

## Purpose

Manage multiple PHP versions, change the default `php` alias, and use version-based aliases.

## Usage

```bash
plumectl php list
plumectl php install 8.3
plumectl php use 8.3
plumectl php alias list
plumectl php alias set php83 8.3
plumectl php alias default 8.3
plumectl php ext sync all
plumectl php ext sync 8.4
plumectl php ext doctor --strict
plumectl php ext resolve all
plumectl php ext resolve 8.4
plumectl php shim install
eval "$(plumectl php shim env)"
php8.4 -v
php-fpm-8.4 -v
plumectl doctor php
plumectl doctor php --strict
```

## Parameters

- `install <version>`
- `use <version>` (changes active/default version)
- `alias set <name> <version>`
- `alias default <version>`
- `ext sync <version|all> [--strict|--no-strict]`
- `ext doctor [--strict]`
- `ext resolve <version|all>`
- `shim install|env|list|remove`

Native mode behavior:

- `php install <version>`:
  - adds the version to the `PLUME_PHP_INSTALLED_VERSIONS` list
  - creates a canonical alias automatically (`8.4 -> php84`)
- `php use <version|alias>`:
  - updates `PLUME_PHP_DEFAULT_VERSION` and `PLUME_PHP_VERSION`
  - if the selected version is not in the list, adds it automatically
- Configuration is persisted to `~/.config/plume/state/php.env` (or `PLUME_STATE_DIR/php.env`).
- `php shim install`:
  - creates host shim files from the `PLUME_PHP_INSTALLED_VERSIONS` list
  - examples: `php8.4`, `php84`, `php-fpm-8.4`, `php-fpm84`
  - default directory: `~/.config/plume/shims`
- `php shim env`:
  - prints an export line to add the shim directory to `PATH`
  - also prints shell aliases for all installed versions except the default:
    - `php81 -> php8.1`
    - `phpfpm81 -> php-fpm-8.1`
  - the default `php` binary is unchanged; only target commands like `php8.4` become active

Extension contract (hybrid: preset + toggle + matrix):

- Preset layer:
  - `PLUME_PHP_EXT_PRESET=none|laravel-core|queue|media|full`
  - optional version-based preset override: `PLUME_PHP_EXT_PRESET_81`, `..._84`
- Matrix layer:
  - `PLUME_PHP_EXTENSIONS_GLOBAL` applies to all versions.
  - `PLUME_PHP_EXTENSIONS_81`, `PLUME_PHP_EXTENSIONS_82`, ... define version-specific extra extension sets.
- Toggle layer:
  - global enable: `PLUME_PHP_EXT_ENABLE_REDIS=true`
  - version-based enable: `PLUME_PHP_EXT_ENABLE_84_XDEBUG=true`
  - version-based disable: `PLUME_PHP_EXT_DISABLE_84_IMAGICK=true`
- Resolution order:
  - `preset + matrix + enable toggles - disable toggles`
  - disable toggle always has the final say.
- `php ext resolve` shows the final extension list for the relevant version(s).
- `php ext sync` tries to install missing extensions on the relevant version(s) and verifies them.
- With `PLUME_PHP_EXTENSIONS_STRICT=true`, the command returns `exit 2` when an extension cannot be verified.
- During `services up php`, auto-sync scope is set by `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=matrix|target|default`.

## Output / Exit Codes

- `0`: success
- `2`: validation/prereq/supported-version error

## Examples

```bash
plumectl php install 8.2
plumectl php use 8.2
plumectl php alias set php82 8.2
plumectl services up php --mode=native
plumectl services up php --mode=native --version=php82
plumectl php shim install
eval "$(plumectl php shim env)"
php8.4 -v
php-fpm-8.4 -v
```

## Error scenarios

- Unsupported PHP version
- Alias name conflict
- Missing permission to change the default alias
- Target version binary not found on host (can fail-fast with `doctor php --strict`)

## Phase 6 note

- `services install php --version=<alias|version>` and `services up php --version=<alias|version>`:
  - resolve aliases such as `php`, `default`, `php83` via `PLUME_PHP_DEFAULT_VERSION` / `PLUME_PHP_ALIAS_*`.
  - if the resolved version is not in `PLUME_PHP_INSTALLED_VERSIONS`, the command fails with `exit 2`.
- Native host binary provisioning:
  - `services install php --mode=native --version=<x.y>` tries to install and verify the host CLI/FPM binary.
  - On success, it automatically adds the version to php matrix state (`php.env`).
- Native FPM service start (`services up php82`, `--version=8.2`): on macOS `brew services start php@x.y`; before start, pool `listen` is aligned to the canonical unix socket (`/opt/homebrew/var/run/php@x.y-fpm.sock`) (D-107); see [services.md](./services.md).

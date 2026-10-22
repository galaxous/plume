# macOS permissions

Canonical detail: [operations/macos-permissions](/operations/macos-permissions).

## What Plume needs

- **TCC** — if project paths live under Desktop / Documents / Downloads, Terminal (or your IDE) needs Full Disk Access / folder access so nginx/php-fpm can serve files.
- **FDA for binaries** — Full Disk Access for Homebrew `nginx` / `php-fpm` binaries when they read restricted paths (not for `plume.sh` itself).

## Interactive helper

```bash
plumectl init permissions --interactive
```

Daily macOS tips: [local-dev-macos](/operations/local-dev-macos).

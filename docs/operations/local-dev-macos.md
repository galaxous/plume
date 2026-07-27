# macOS local development (Herd-like ergonomics)

This guide complements [first-run-onboarding.md](./first-run-onboarding.md) and [macos-permissions.md](./macos-permissions.md) for day-to-day Laravel work on a single Mac.

## Recommended `~/.config/plume/.env` knobs

| Variable | Local dev recommendation | Why |
|---|---|---|
| `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE` | `target` | On `services up php`, sync/verify extensions only for the PHP version being started — not every row in `PLUME_PHP_INSTALLED_VERSIONS`. Avoids slow or failing pecl runs across the full matrix. |
| `PLUME_PHP_EXTENSIONS_AUTO_SYNC` | `true` | Keep on so the active PHP version still matches your extension contract. |
| `PLUME_PHP_EXTENSIONS_STRICT` | `true` (default) | Fail fast when an extension is missing. Set `false` only if you intentionally run with partial extensions and accept WARN-only verify. |
| `PLUME_SITE_NGINX_STRICT` | `false` | Typical local dev; enable strict when you want publish to fail if nginx include dir is wrong. |

Preset: `templates/native-local.env.example` uses `AUTO_SYNC_PROFILE=target`. Apply to an existing file manually or re-init from that template with care (`env init --force` overwrites).

CI and smoke tests often set `PLUME_PHP_EXTENSIONS_AUTO_SYNC=false` for speed and hermetic installs — that is not the same as daily native dev on your machine.

## Project paths (TCC)

Prefer Laravel roots under **`~/Sites`** or **`~/Code`**, not `~/Desktop`, `~/Documents`, or `~/Downloads`. Homebrew **nginx** and **php-fpm** are separate processes; macOS TCC can block them from reading `public/index.php` (browser: "No input file specified").

When you register a site under a protected folder, Plume warns on `site add` / `site update --path` and sets `tcc_risk: true` on `site check --json`.

Remediation:

1. Move the project (example below), then `site update --path=... --publish --reload`
2. Or grant **Full Disk Access** to Homebrew nginx and php-fpm binaries — **not** `plume.sh` (see `init onboarding` / `init permissions --interactive`)

## Verify

```bash
./plume.sh site check <site-id>
./plume.sh doctor web --mode=native    # macos-site-tcc
./plume.sh doctor php                  # MACOS_TCC
./plume.sh init permissions --interactive
```

## Example: move a site off Desktop

```bash
mkdir -p ~/Sites
mv ~/Desktop/Projects.nosync/tunnelion ~/Sites/tunnelion
./plume.sh site update site-1775207595-23239 \
  --path="$HOME/Sites/tunnelion" --publish --reload
```

Adjust site id and paths to match your registry.

## Related

- [site.md](../commands/site.md) — TCC troubleshooting
- [env.md](../commands/env.md) — global env presets
- D-110 — local dev defaults and TCC warnings on site path changes

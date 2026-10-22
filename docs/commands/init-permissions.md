# `init permissions` Command

## Purpose

List which permissions the user must grant on macOS native mode for nginx/php-fpm and project file access; optionally open System Settings. Plume is a CLI script — the list has **no Plume app or `plume.sh`**; add Homebrew **nginx** and **php-fpm** binaries to Full Disk Access.

## Usage

```bash
plumectl init permissions
plumectl init permissions --open
plumectl init permissions --reveal
plumectl init permissions --open --reveal
plumectl init permissions --interactive
```

## Parameters

- `--open`: Print nginx/php-fpm paths first, warn, then try to open the Full Disk Access privacy pane (`open x-apple.systempreferences:...`)
- `--reveal`: Open the nginx binary directory in Finder (Homebrew `.../opt/nginx/bin` or `command -v nginx` directory)
- `--interactive`: If TCC risk exists (registered sites under Desktop/Documents/Downloads), show a tty menu: open FDA, suggest move to ~/Sites, continue, cancel. This flag forces `PLUME_INTERACTIVE=true` (even when IDE terminal `-t` detection fails).

## Output / Exit code

- `0`: success (informational message outside macOS)
- `2`: `--open` or `--reveal` failed

Output always includes this warning:

```text
Plume is a CLI script — do NOT add plume.sh or a "Plume" app in Full Disk Access.
```

Then resolved `nginx` and `php-fpm` paths (`command -v`, `brew --prefix`) are listed; optionally Terminal/iTerm path.

## Examples

```bash
plumectl init permissions
plumectl init permissions --open
plumectl doctor web    # macos-site-tcc line
plumectl doctor php    # MACOS_TCC line
```

## Error scenarios

- linux/windows: command prints guidance; the grant list is macOS-specific
- `--open` with no GUI session (SSH headless): manual steps required; use binary paths from the output
- If binary not found, placeholder hints are printed (nginx/php install missing)

## Related

- `docs/operations/macos-permissions.md` (automation vs manual FDA)
- `docs/commands/site.md` (TCC troubleshooting)
- `init onboarding`, D-099, D-100

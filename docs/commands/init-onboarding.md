# `init onboarding` Command

## Purpose

Print a checklist on first run so the user does not have to discover TCC, nginx 8080, project path, and php-fpm services one by one. On macOS it clearly lists the **nginx/php-fpm binary paths to add** for Full Disk Access (not Plume or `plume.sh`).

## Usage

```bash
./plume.sh init onboarding
./plume.sh init onboarding --fix
./plume.sh init onboarding --open-settings
./plume.sh doctor onboarding
./plume.sh doctor onboarding --fix
```

## Parameters

- `--fix`: Safe host fixes (macOS + Homebrew: `brew services start nginx` and php/php@X for installed PHP formulas). **Does not open System Settings.**
- `--open-settings` (macOS): Tries to open the Full Disk Access privacy pane; prints the binary list first. Exit `2` on failure.

## Output / Exit code

- `0`: informational output complete
- `2`: unknown flag or Settings could not be opened with `--open-settings`

## Checklist (summary)

| OS | Items |
|----|-------|
| macOS | Dev/repo note, TCC / Desktop-Documents warning, `~/Sites` or `~/Code`, nginx 80 vs 8080, nginx/php-fpm paths for FDA, `brew services` hints |
| linux | Project path, nginx port, systemctl hints |
| windows | Limited native mode; WSL2/docker-lite recommendation |

If you run via `./plume.sh` from the repo root, the output highlights the **Dev / repo checkout** line; FDA is often optional (path outside Desktop).

If the host profile is missing, onboarding first runs `init host` detection.

## Examples

```bash
./plume.sh env init
./plume.sh init onboarding
./plume.sh init onboarding --fix              # start brew nginx/php
./plume.sh init permissions --open            # FDA pane + binary list
./plume.sh init permissions --open --reveal   # + nginx bin directory in Finder
```

## Error scenarios

- `--fix` / `--open-settings` outside macOS: the list is still printed; macOS-only flags are explained in an info line
- `--open-settings` on macOS without deep-link support: exit `2`; use paths from `init permissions` output for manual GUI steps

## Related

- `init permissions`, `doctor web` (`macos-site-tcc`), `docs/commands/services-web.md`
- `docs/operations/first-run-onboarding.md`
- Decision: D-099

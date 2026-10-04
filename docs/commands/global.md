# Global Commands

## Purpose

Definition of behaviors common to all commands.

## Usage

```bash
./plume.sh --help
./plume.sh --version
./plume.sh --json services supported
./plume.sh --quiet services update
./plume.sh --env-file /path/to/custom.env services status
```

## Parameters

- `--help`, `-h`: help text
- `--version`, `-v`: version info
- `--json`: JSON output on supported commands
- `--yes`: non-interactive approval mode (phase2 baseline); also skips macOS permission/brew prompts
- `--quiet`: suppress info logs
- `--env-file <path>`: load that file instead of the default `.env`

For macOS permission menu and host install approvals, `PLUME_NONINTERACTIVE=1` can also be used (see `docs/operations/macos-permissions.md`).

## Notes

- Without `--env-file`, plume loads the global env file:
  - `~/.config/plume/.env` (or `PLUME_GLOBAL_ENV_FILE`)
- If global env is missing and an example exists, it is bootstrapped automatically:
  - first `~/.config/plume/.env.example`
  - then plume built-in example (`templates/native-core.env.example`)
  - otherwise `.env.example` in the working directory
- For presets, prefer `env init --from=...`:
  - local: `templates/native-local.env.example` (extension auto-sync `matrix`)
  - prod: `templates/native-prod.env.example` (extension auto-sync `target`)
- `PLUME_*` / `PMA_*` env values provided externally when running a command are not overridden by global env (CLI/env takes precedence).

## Output / Exit Codes

- `0`: success
- `1`: general/runtime error
- `2`: validation/prereq/user-correctable error

## Examples

```bash
./plume.sh --json services status
./plume.sh --env-file /tmp/plume.env prereq check
```

## Error scenarios

- Unknown command
- `--env-file` given without a path
- Given `--env-file` file not found

## Naming note

- Official binary: `plumectl`
- Test-stage runner: `./plume.sh`
- Optional alias: `plume`

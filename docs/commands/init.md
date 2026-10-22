# `init` Commands

## Purpose

Activate plume PHP shims in the shell environment with one command; host profile and onboarding on first install.

Subcommands:

- `init shell` — this file
- `init host` — [init-host.md](init-host.md)
- `init onboarding` — [init-onboarding.md](init-onboarding.md)
- `init permissions` — [init-permissions.md](init-permissions.md)

## Usage

```bash
plumectl init shell
plumectl init host
plumectl init onboarding
plumectl init permissions --open
plumectl init shell --shell=zsh
plumectl init shell --shell=bash
plumectl init shell --rc=$HOME/.zshrc --force
```

## Parameters

- `shell`
  - `--shell=zsh|bash`: target shell type
  - `--rc=/abs/path`: custom rc file
  - `--force`: delete the existing plume block and rewrite it

## Behavior

- `php shim install` runs automatically.
- This block is added to the shell rc file:
  - `# >>> plume php shim >>>`
  - `eval "$(<plume-exec> php shim env)"`
  - `# <<< plume php shim <<<`
- On every shell start this loads:
  - shim `PATH` activation
  - aliases such as `php81`, `php82`, `phpfpm81` for installed PHP versions other than the default
- Re-running does not write duplicates (idempotent).

## Output / Exit Codes

- `0`: success
- `2`: invalid option/shell or write error

## Examples

```bash
plumectl php install 8.4
plumectl init shell --shell=zsh
source ~/.zshrc
php8.4 -v
```

## Error scenarios

- Unsupported shell (`fish`, etc.)
- No write permission on the RC file
- plume executable cannot be resolved

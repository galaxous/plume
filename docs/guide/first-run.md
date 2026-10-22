# First-run onboarding

Canonical runbook: [operations/first-run-onboarding](/operations/first-run-onboarding).

## Checklist

1. Install CLI — [Install](./install.md)
2. `plumectl env init` — creates `~/.config/plume/.env`
3. `plumectl init host` — writes `host.env` (OS / package manager / paths)
4. `plumectl init onboarding` — guided first steps (`--fix` if needed)
5. macOS: `plumectl init permissions --interactive` — see [macOS permissions](./macos-permissions.md)
6. `plumectl doctor workspace` / `plumectl doctor web`
7. `plumectl services up @core --mode=native`
8. `plumectl site add … --publish`

Stack manifest (optional): `~/.config/plume/services.yml` — [services-manifest](/operations/services-manifest).

# Plume

Plume is a 3-mode (`native`, `docker-lite`, `laradock-bridge`) operations utility for Laravel projects on Linux/macOS.

**Current status:** Phases 1–28 are complete (Phase 7 docker-lite is **beta-frozen**). P3 Release: Homebrew + Packagist ready. Next candidate: **P2 meilisearch/minio** (see [implementation/future-roadmap.md](implementation/future-roadmap.md)).

Detailed progress: [implementation/phase-tracker.md](implementation/phase-tracker.md)

## Naming Policy

- Product: `Plume`
- Official CLI binary: `plumectl`
- Local test wrapper: `./plume.sh` (repo checkout; same CLI as `plumectl`)
- Optional alias: `plume`
- Repository: `plume` (GitHub); Packagist/formula alias: `laravel-plume`

## Feature Summary

- Modular CLI (`bin/plumectl`, `lib/*`), global flags (`--json`, `--yes`, `--quiet`, `--env-file`)
- Modes: `mode current`, `mode use`, `mode path` (laradock-bridge context)
- Site registry and lifecycle: `site add|list|check|update|publish|remove|modes`, nginx/apache2/caddy, TLS, hosts sync, strict publish
- Services: `services supported|status|install|up|down|update|health|logs|use|url|credentials`, native Laradock-like alias contract (`php-fpm`, `workspace`, `@core/@web/@db/@cache/@queue`)
- Native PHP: `php list|install|use|alias`, `php ext sync|resolve|doctor`, `php shim`, `init shell`, `env where|init`
- Laradock-bridge: bootstrap, sync, runtime parity test package
- Ops: `doctor`, `backup`, `deploy plan|apply|rollback|failback`, `security`, `monitor`, `project init`
- OS prereq: `prereq check|explain` (`brew` / `apt` / `dnf`)

In native mode, **PHP** gets real host installation (`brew`/`apt`). Other services default to state/port orchestration; for real host provisioning set `PLUME_NATIVE_HOST_PROVISION=true` (see [docs/commands/services.md](docs/commands/services.md)). On macOS, **Mailpit** is supported via native brew (`services up mailpit`; D-109).

## Local Run

From the repo root:

```bash
plumectl --help
plumectl version
plumectl mode current
```

Default global env: `~/.config/plume/.env` (can be created with `env init`). Native stack manifest (Laradock-like): `~/.config/plume/services.yml` — see [docs/operations/services-manifest.md](docs/operations/services-manifest.md).

First-run onboarding: [docs/operations/first-run-onboarding.md](docs/operations/first-run-onboarding.md)

```bash
plumectl env init
plumectl init host          # also created automatically (PLUME_AUTO_HOST_BOOTSTRAP)
plumectl init onboarding
plumectl doctor web
```

## Installation (Release)

Step-by-step guide (Homebrew + Linux distros + Packagist): **[docs/operations/install.md](docs/operations/install.md)**

```bash
# macOS
brew tap galaxous/plume https://github.com/galaxous/plume && brew install plumectl

# Linux (Debian/Ubuntu/Fedora/…)
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  sudo env PLUME_REF=v0.3.0 PREFIX=/usr/local bash

# Composer (macOS + Linux)
composer global require galaxous/laravel-plume

# Development clone
make install
```

Maintainer release: [docs/operations/release.md](docs/operations/release.md)  
Pre-release smoke: [docs/operations/release-readiness.md](docs/operations/release-readiness.md)

## Example Commands

```bash
plumectl site add --path=/path/to/laravel/public --domain=myapp.test --server=nginx --publish
plumectl services use mariadb --mode=native
plumectl services up @core --mode=native
plumectl php use 8.3
plumectl doctor check --mode=native --deep
plumectl deploy plan --mode=native
plumectl --yes deploy apply --mode=native --skip-backup
```

## Documentation Map

- **Docs site (VitePress):** [galaxous.github.io/plume](https://galaxous.github.io/plume/) — local: `cd docs && npm install && npm run docs:dev`
- Guide: `docs/guide/`
- Commands: `docs/commands/`
- Operations: `docs/operations/`
- Contracts: `docs/contracts/`
- Implementation context: `implementation/` (phase tracker, ADRs — not part of the public site)
## Test (Release Matrix)

Single entry point (same steps as CI; recommended before publish):

```bash
./tests/run_smoke_suite.sh              # default: --release
./tests/run_smoke_suite.sh --ci         # identical to .github/workflows/smoke-tests.yml
```

Extra depth (optional):

```bash
./tests/run_smoke_suite.sh --phase11-full   # all phase11 smoke scripts (except matrix)
PLUME_RUN_LINUX_TESTS=1 ./tests/run_smoke_suite.sh --all   # all smoke scripts
./tests/run_smoke_suite.sh --all --linux    # --all + Linux prereq matrix (phase3)
```

Manual matrix (legacy doc compatibility; `phase10_e2e_matrix` already runs `phase11_e2e_matrix`):

```bash
./tests/phase10_e2e_matrix_smoke.sh
./tests/phase11_e2e_matrix_smoke.sh
PLUME_RUN_LINUX_TESTS=1 tests/phase3_prereq_smoke.sh
```

Integration (real host package install, optional):

```bash
PLUME_RUN_INTEGRATION=1 ./tests/phase12_native_host_provision_smoke.sh
```

Details: [docs/operations/release-readiness.md](docs/operations/release-readiness.md). AI-assisted development and smoke lessons: [docs/operations/ai-assisted-development.md](docs/operations/ai-assisted-development.md).

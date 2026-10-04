# Phased Plan (10-Phase Gate Model)

## Vision

Plume is a single 3-mode utility for Linux/macOS:

1. `native`
2. `docker-lite`
3. `laradock-bridge`

Required output in every phase:

- Working feature
- Test evidence
- Documentation update
- Decision log entry

## Phase 1 - Foundation & Repo Standards

- Modular shell rules, directory contract, naming convention
- Official adoption of the 10-phase gate model
- Documentation requirements committed into the repo
- Naming policy:
  - Product name: `Plume`
  - Official binary: `plumectl` (to reduce Linux util collision)
  - Optional short alias: `plume`
  - GitHub repo: `laravel-plume`

## Phase 2 - CLI Core & Router

- Thin entrypoint + command router
- Global flags, help, exit-code standard
- Skeleton for command families (`mode`, `site`, `services`, `prereq`, `status`, `project`, `deploy`, `backup`)
- Unified `.env` contract:
  - all shared variables in `.env.example`
  - mode-specific variables in separate prefix blocks (`NATIVE`, `DOCKER_LITE`, `LARADOCK_BRIDGE`)
- Privilege model skeleton:
  - Install/update steps require sudo/root
  - Runtime operations (up/down/logs/health) can run without root

## Phase 3 - OS Detection & Core Prereq Guard

- macOS/Linux detection
- Linux package manager detection (`apt`, `dnf`)
- Fail-fast prereq check (`command -v`) and install guidance
- OS security preflight (`ufw/firewalld`, `selinux/apparmor`) check draft

## Phase 4 - Site Registry & Onboarding (Nginx First)

- Central site registry (`index.yaml` + site yaml records)
- `plumectl site add/list/remove/check`
- Interactive prompt for path/domain
- Nginx config publish + hosts + reload
- `plume.yml` (project-local site config manifest) not required in testing phases; schedule planned after phase-4 validation.
- Fast Laravel onboarding:
  - `project init` (composer install, `.env` prep, `key:generate`, `storage:link`)
  - optional `migrate`, `db:seed`, `npm install`, `npm run build/dev`

## Phase 5 - Multi-Webserver Parity (Apache2/Caddy)

- Add Apache2/Caddy adapters
- Config generation from the shared registry model
- Domain/path conflict rules and override flow

## Phase 6 - Native Service Orchestration

- Native mode service adapters
- Port intelligence (default -> fallback -> state)
- First version of service install/start/stop/status
- `services supported --mode=native` command and docs
- Minimal default profile:
  - default true: php, composer, mariadb, nginx
  - all other services default false
- `services update` reconcile:
  - detect services flipped to true later in config
  - auto install + start them
- Service version management:
  - `services install <name> --version=<x.y.z>`
  - per-service pinned version record
- PHP multi-version:
  - multiple PHP versions can be installed/managed
  - default `php` alias points to the selected version
  - alternative aliases (`php82`, `php83`, etc.) are defined
- Laravel runtime services:
  - scheduler (cron/systemd timer)
  - queue worker
  - horizon (+ supervisor)
  - optional reverb/websocket and octane process management
- Non-root operations:
  - root not required for logs, health, status, service up/down
- Horizon process management:
  - `supervisor` install and config publish
  - supervisor program template and health check for Horizon

## Phase 7 - Docker-Lite Mode

- Minimal compose/workspace model
- `compose up/down/status` and health-check
- Registry alignment with docker-lite site publish
- `services supported --mode=docker-lite` output parity
- Goal: docker-lite parity for most native services
- Horizon runtime model:
  - supervisor or equivalent process manager strategy inside docker-lite
- Version parity:
  - service version selection via docker-lite image tags
  - PHP version and alias behavior aligned with native
- Status note (2026-03-10):
  - Phase locked as `beta-frozen`.
  - Remaining lightweight/local+production ergonomics moved to backlog.

## Phase 8 - Laradock Bridge Mode

- Laradock auto-discovery
- Bridge inspect/sync
- Safe integration with an existing laradock stack
- Priority note (2026-03-10):
  - Active development focus moved to this phase.
  - Goal: native + laradock-bridge single command surface parity.

## Phase 9 - Observability, Ops, Production

- `doctor`, `health`, `logs`, `monitor summary`
- Log rotation, status report, backup/restore (site registry)
- Server install/update/upgrade operations
- TLS/certificate automation (native + docker-lite compatible script)
- Secrets management (env/file based + policy)
- Rollback/failback mechanism (revert if config apply fails)
- Optional backup scope expansion: config + db dump
- Pinned version + optional auto-update strategy
- DNS management: not in this phase; backlog for a later phase
- Production deploy flow:
  - maintenance/zero-downtime strategy
  - migration safety steps
  - queue/horizon recycle (`queue:restart`, `horizon:terminate`)
  - post-deploy health gate and automatic rollback

## Phase 10 - Stabilization, Release, Adapter-Readiness

- E2E/regression matrix (3 modes x main scenarios)
- CLI output contract stabilization
- Complete full documentation for fast `plume-adapter` project integration
- Full E2E requirement (smoke is not enough)
- Herd parity checklist + beyond feature checklist closure report

## Phase Gate Rule

Completion criteria for a phase:

1. Tests passed
2. Command docs updated
3. `implementation/05-decision-log.md` updated
4. Next-phase risks written
5. Laravel project lifecycle scenario verified for the related phase

# Herd Parity + Beyond Checklist

Goal: Guarantee that Plume delivers an experience equal to (and beyond) Laravel Herd for local and production.

## Parity (Core)

- [x] Multi PHP version management (phase 11: `php list|install|use`, matrix state)
- [x] Default PHP switching + alias management (`php use`, `php alias`, shims)
- [x] Local domain onboarding (`*.test`-like) (site add + `PLUME_SITE_HOSTS_SYNC`)
- [x] TLS local cert automation (`security cert`, `site --cert-id`)
- [x] Fast site add/remove
- [x] Nginx/Apache2/Caddy support
- [x] Composer + Node dev workflow integration (Phase 27 / D-154 MVP; stretch: node_version/nvm)

## Beyond (Plume Targets)

- [x] Native mode + Docker-lite + Laradock bridge together (3 modes, mode switch)
- [x] Service version pinning (mysql/redis/mariadb/postgres/php) (env + state metadata)
- [x] Native DB/cache stack host provision (Phase 17: postgres, phpmyadmin, mongodb, rabbitmq, mongo_webui, redis_webui; D-119–D-120)
- [x] Horizon + Supervisor full integration (native contract + dependency guard)
- [x] Queue/Scheduler runtime management (Phase 15 baseline: `schedule status|list|run-once|cron-install`, `queue status|list`; D-111–D-114 — see [schedule.md](../docs/commands/schedule.md), [queue.md](../docs/commands/queue.md); full worker/supervisor host install remains within manifest limits — D-113)
- [x] Production deploy orchestration + rollback (`deploy apply` Phase 13, D-087; `deploy rollback|failback`; see [deploy.md](../docs/commands/deploy.md))
- [x] Secrets policy + firewall/os security checks (phase 9 baseline)
- [x] Optional backup (config + db scope)
- [x] Pinned release + optional auto-update (Phase 28 / D-155: VERSION + Homebrew/Packagist; upgrade via brew/composer)
- [x] JSON contract for critical commands (baseline; golden snapshots phase 14)

## Laravel Ecosystem (Optional but Planned)

- [x] Mail sandbox (Mailpit native macOS; D-109) — `services install|up mailpit`, manifest `mailpit.enabled`; see [services.md](../docs/commands/services.md) (Mailpit), [services-manifest.md](../docs/operations/services-manifest.md), [services-provision.md](../docs/commands/services-provision.md)
- [ ] Meilisearch/OpenSearch option
- [ ] MinIO/S3-compatible local object storage
- [ ] Websocket stack (Reverb/Soketi) runtime management
- [ ] Cache/session/store driver compatibility validation
- [x] `schedule:list`, `queue:failed` artisan wrappers (`schedule list`, `queue list`; D-112 — [schedule.md](../docs/commands/schedule.md), [queue.md](../docs/commands/queue.md))
- [ ] `about` and other extended artisan health probes

## Laravel Project Lifecycle Coverage

- [x] `project init` (bootstrap)
- [x] Project-local `plume.yml` MVP (`project config show`, `site add` mode/php hint; D-117–D-118 — [project-plume-yml.md](../docs/operations/project-plume-yml.md), [project-config.md](../docs/commands/project-config.md))
- [x] `site add` + web server publish
- [x] `services install/up/status` (command surface + native PHP host install; other services opt-in host provision)
- [x] `deploy run` + health gate (`deploy apply` phase 13)
- [x] `monitor summary` + incident triage (phase 9 runbook)

## Phase 4 Impact Note

- 2026-03-06: Completed the foundation for `site add/list/check/remove`.
- Central site registry model (`~/.config/plume/sites`) was made operational.
- Publish flow completed with snippet + optional reload/hosts/strict publish (phase 5+).
- **2026-07-29 (Phase 16):** `plume.yml` MVP at project root — `project.mode`, `project.php_version`, `project.type`; no automatic sync with registry; merge rules D-117. Phase-4 single-field `mode` behavior was extended with `project.mode` precedence.

## Phase Mapping

- Phases 4-5: onboarding + web servers
- Phases 6-7: services + php versions + runtime
- Phase 9: production ops + deploy + rollback + observability
- Phase 10: parity checklist closure report
- Phase 13: `deploy apply` orchestration
- Phase 15: scheduler/queue CLI (D-111–D-114), native Mailpit host provision (D-109); gate D-115–D-116 — see [phase-15.md](phases/phase-15.md), [11-status-2026-07-28.md](11-status-2026-07-28.md)
- Phase 16: project `plume.yml` v2 MVP (D-117–D-118) — see [phase-16.md](phases/phase-16.md), [11-status-2026-07-29.md](11-status-2026-07-29.md)
- Phase 17: native stack host parity (D-119–D-120) — see [phase-17.md](phases/phase-17.md), [11-status-2026-08-04.md](11-status-2026-08-04.md)

## Phase 16 Impact Note

- 2026-07-29: `lib/common/plume_yml.sh`, `project config show`, `site add` manifest hint; stretch (registry sync, services.enabled) backlog.

## Phase 15 Impact Note

- 2026-07-28: scheduler/queue MVP closed; Mailpit native brew path (D-109) marked as mail sandbox on the parity checklist.
- 2026-09-29: Composer/Node MVP (D-154) closed; still open: Meilisearch/MinIO/Reverb, pinned auto-update stretch, `about` probe.

## Phase 1 Impact Note

- 2026-03-06: CLI foundation, mode selection, and service visibility/reconcile skeleton prepared.
- Parity checklist items were not completed in this phase; only the technical groundwork was created.

## Phase 2 Impact Note

- 2026-03-06: Router command families and the global flag standard were enabled.
- With the `--json` baseline, a parseable output foundation for adapter-readiness was created.
- Parity items are still open; this phase only stabilized the pre-orchestration CLI core layer.

## Phase 3 Impact Note

- 2026-03-06: OS-aware prereq guard and package-manager detection (`brew/apt/dnf`) were enabled.
- Root boundary (root requirement for install/update) was enforced at the code level.
- For the parity goal, this phase provided a deterministic preflight layer across local/prod differences.

## Phase 10 Closure Review

- 2026-04-03: parity/beyond checklist was re-evaluated.
- Closed baseline:
  - local site lifecycle + multi webserver adapters + TLS cert/site binding
  - native + laradock-bridge operations parity
  - rollback/failback + backup + security/secrets + monitor chain
- Next roadmap candidates:
  - command-level golden JSON snapshots
  - CI matrix automation
  - exit from docker-lite beta-frozen scope (separate phase)

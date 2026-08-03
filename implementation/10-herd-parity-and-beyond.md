# Herd Parity + Beyond Checklist

Amac: Plume'in local ve production'da Laravel Herd'unkine denk (ve ustu) deneyim sunmasini garanti etmek.

## Parity (Core)

- [x] Multi PHP version yonetimi (phase 11: `php list|install|use`, matrix state)
- [x] Default PHP switching + alias management (`php use`, `php alias`, shims)
- [x] Local domain onboarding (`*.test` benzeri) (site add + `PLUME_SITE_HOSTS_SYNC`)
- [x] TLS local cert otomasyonu (`security cert`, `site --cert-id`)
- [x] Hizli site ekleme/kaldirma
- [x] Nginx/Apache2/Caddy destegi
- [ ] Composer + Node dev workflow entegrasyonu (workspace laradock/docker-lite agirlikli)

## Beyond (Plume Targets)

- [x] Native mode + Docker-lite + Laradock bridge bir arada (3 mod, mode switch)
- [x] Service version pinning (mysql/redis/mariadb/postgres/php) (env + state metadata)
- [x] Horizon + Supervisor tam entegrasyon (native contract + dependency guard)
- [x] Queue/Scheduler runtime yonetimi (Faz 15 baseline: `schedule status|list|run-once|cron-install`, `queue status|list`; D-111–D-114 — bkz. [schedule.md](../docs/commands/schedule.md), [queue.md](../docs/commands/queue.md); tam worker/supervisor host kurulumu hâlâ manifest sinirlari icinde — D-113)
- [x] Production deploy orchestration + rollback (`deploy apply` Faz 13, D-087; `deploy rollback|failback`; bkz. [deploy.md](../docs/commands/deploy.md))
- [x] Secrets policy + firewall/os security checks (phase 9 baseline)
- [x] Optional backup (config + db scope)
- [ ] Pinned release + optional auto-update (manual release workflow; auto-update backlog)
- [x] Critical commands icin JSON contract (baseline; golden snapshots faz 14)

## Laravel Ecosystem (Optional but Planned)

- [x] Mail sandbox (Mailpit native macOS; D-109) — `services install|up mailpit`, manifest `mailpit.enabled`; bkz. [services.md](../docs/commands/services.md) (Mailpit), [services-manifest.md](../docs/operations/services-manifest.md), [services-provision.md](../docs/commands/services-provision.md)
- [ ] Meilisearch/OpenSearch secenegi
- [ ] MinIO/S3-compatible local object storage
- [ ] Websocket stack (Reverb/Soketi) runtime management
- [ ] Cache/session/store driver uyum dogrulamasi
- [x] `schedule:list`, `queue:failed` artisan sarmalayicilari (`schedule list`, `queue list`; D-112 — [schedule.md](../docs/commands/schedule.md), [queue.md](../docs/commands/queue.md))
- [ ] `about` ve diger genisletilmis artisan health probes

## Laravel Project Lifecycle Coverage

- [x] `project init` (bootstrap)
- [x] Project-local `plume.yml` MVP (`project config show`, `site add` mode/php hint; D-117–D-118 — [project-plume-yml.md](../docs/operations/project-plume-yml.md), [project-config.md](../docs/commands/project-config.md))
- [x] `site add` + web server publish
- [x] `services install/up/status` (command surface + native PHP host install; diger servisler opt-in host provision)
- [x] `deploy run` + health gate (`deploy apply` faz 13)
- [x] `monitor summary` + incident triage (phase 9 runbook)

## Phase 4 Impact Note

- 2026-03-06: `site add/list/check/remove` temelini tamamladı.
- Merkezî site registry modeli (`~/.config/plume/sites`) çalışır hale getirildi.
- publish akışı snippet + opsiyonel reload/hosts/strict publish ile tamamlandi (faz 5+).
- **2026-07-29 (Faz 16):** Proje kokunde `plume.yml` MVP — `project.mode`, `project.php_version`, `project.type`; registry ile otomatik sync yok; merge kurallari D-117. Phase-4 tek alan `mode` davranisi `project.mode` onceligi ile genisletildi.

## Phase Mapping

- Faz 4-5: onboarding + web servers
- Faz 6-7: services + php versions + runtime
- Faz 9: production ops + deploy + rollback + observability
- Faz 10: parity checklist kapanis raporu
- Faz 13: `deploy apply` orchestration
- Faz 15: scheduler/queue CLI (D-111–D-114), native Mailpit host provision (D-109); gate D-115–D-116 — bkz. [phase-15.md](phases/phase-15.md), [11-status-2026-07-28.md](11-status-2026-07-28.md)
- Faz 16: project `plume.yml` v2 MVP (D-117–D-118) — bkz. [phase-16.md](phases/phase-16.md), [11-status-2026-07-29.md](11-status-2026-07-29.md)

## Phase 16 Impact Note

- 2026-07-29: `lib/common/plume_yml.sh`, `project config show`, `site add` manifest hint; stretch (registry sync, services.enabled) backlog.

## Phase 15 Impact Note

- 2026-07-28: scheduler/queue MVP kapandi; Mailpit native brew yolu (D-109) parity checklist'te mail sandbox olarak isaretlendi.
- Acik kalan parity: Composer/Node workspace entegrasyonu, `about` probe, Meilisearch/MinIO/Reverb, pinned auto-update.

## Phase 1 Impact Note

- 2026-03-06: CLI temeli, mode secimi ve service visibility/reconcile iskeleti hazirlandi.
- Bu fazda parity checklist maddeleri tamamlanmadi; sadece teknik zemin olusturuldu.

## Phase 2 Impact Note

- 2026-03-06: Router command aileleri ve global flag standardi devreye alindi.
- `--json` baseline'i ile adapter-readiness icin parse edilebilir cikti zemini olusturuldu.
- Parity maddeleri halen acik; bu faz sadece orchestration oncesi CLI core katmanini stabilledi.

## Phase 3 Impact Note

- 2026-03-06: OS-aware prereq guard ve package-manager detection (`brew/apt/dnf`) devreye alindi.
- Root boundary (install/update root zorunlulugu) kod duzeyinde enforce edildi.
- Parity hedefi acisindan bu faz, lokal/prod farkliliklarinda deterministic preflight katmani sagladi.

## Phase 10 Closure Review

- 2026-04-03: parity/beyond checklist yeniden degerlendirildi.
- Kapanan baseline:
  - local site lifecycle + multi webserver adapters + TLS cert/site binding
  - native + laradock-bridge operasyon parity'si
  - rollback/failback + backup + security/secrets + monitor zinciri
- Sonraki roadmap adayi:
  - command-level golden JSON snapshots
  - CI matrix automation
  - docker-lite beta-frozen kapsamindan cikis (ayri faz)

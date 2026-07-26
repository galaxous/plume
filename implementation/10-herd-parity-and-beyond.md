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
- [ ] Queue/Scheduler runtime yonetimi (kismen; tam scheduler ops backlog)
- [ ] Production deploy orchestration + rollback (`deploy apply` faz 13; rollback mevcut)
- [x] Secrets policy + firewall/os security checks (phase 9 baseline)
- [x] Optional backup (config + db scope)
- [ ] Pinned release + optional auto-update (manual release workflow; auto-update backlog)
- [x] Critical commands icin JSON contract (baseline; golden snapshots faz 14)

## Laravel Ecosystem (Optional but Planned)

- [ ] Mail sandbox (Mailpit/Mailhog) hizli ac-kapa
- [ ] Meilisearch/OpenSearch secenegi
- [ ] MinIO/S3-compatible local object storage
- [ ] Websocket stack (Reverb/Soketi) runtime management
- [ ] Cache/session/store driver uyum dogrulamasi
- [ ] `about`, `queue:failed`, `schedule:list` gibi artisan health probes

## Laravel Project Lifecycle Coverage

- [x] `project init` (bootstrap)
- [x] `site add` + web server publish
- [x] `services install/up/status` (command surface + native PHP host install; diger servisler opt-in host provision)
- [x] `deploy run` + health gate (`deploy apply` faz 13)
- [x] `monitor summary` + incident triage (phase 9 runbook)

## Phase 4 Impact Note

- 2026-03-06: `site add/list/check/remove` temelini tamamladı.
- Merkezî site registry modeli (`~/.config/plume/sites`) çalışır hale getirildi.
- publish akışı snippet + opsiyonel reload/hosts/strict publish ile tamamlandi (faz 5+).
- `plume.yml` tabanlı site manifest desteği bu fazın test kapsamının dışında tutuldu; sonraki fazlarda (post-testing) project-local manifest standardı planlanıyor.

## Phase Mapping

- Faz 4-5: onboarding + web servers
- Faz 6-7: services + php versions + runtime
- Faz 9: production ops + deploy + rollback + observability
- Faz 10: parity checklist kapanis raporu

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

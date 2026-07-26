# Phased Plan (10-Phase Gate Model)

## Vizyon

Plume, Linux/macOS icin 3 modlu tek utility:

1. `native`
2. `docker-lite`
3. `laradock-bridge`

Her fazda zorunlu cikti:

- Calisan ozellik
- Test kaniti
- Dokumantasyon guncellemesi
- Decision log kaydi

## Faz 1 - Foundation & Repo Standards

- Moduler shell kurallari, klasor sozlesmesi, naming convention
- 10 faz gate modelinin resmi kabul edilmesi
- Dokumantasyon zorunlulugu kurallarinin repo icine alinmasi
- Naming policy:
  - Urun adi: `Plume`
  - Resmi binary: `plumectl` (linux util cakismasini azaltmak icin)
  - Opsiyonel kisa alias: `plume`
  - GitHub repo: `laravel-plume`

## Faz 2 - CLI Core & Router

- Ince entrypoint + komut router
- Global flags, help, exit-code standardi
- Komut aileleri icin iskelet (`mode`, `site`, `services`, `prereq`, `status`, `project`, `deploy`, `backup`)
- Unified `.env` contract:
  - tum ortak degiskenler `.env.example` icinde
  - mode-ozel degiskenler ayri prefix bloklariyla (`NATIVE`, `DOCKER_LITE`, `LARADOCK_BRIDGE`)
- Yetki modeli iskeleti:
  - Kurulum/guncelleme adimlari sudo/root gerektirir
  - Runtime operasyonlari (up/down/logs/health) root olmadan calisabilir

## Faz 3 - OS Detection & Core Prereq Guard

- macOS/Linux tespiti
- Linux package manager tespiti (`apt`, `dnf`)
- Fail-fast prereq kontrolu (`command -v`) ve install yonergesi
- OS security preflight (`ufw/firewalld`, `selinux/apparmor`) kontrol taslagi

## Faz 4 - Site Registry & Onboarding (Nginx First)

- Merkezi site registry (`index.yaml` + site yaml kayitlari)
- `plumectl site add/list/remove/check`
- Interactive prompt ile path/domain alma
- Nginx config publish + hosts + reload
- `plume.yml` (project-local site config manifest) not required in testing phases; schedule planned after phase-4 validation.
- Laravel hizli onboarding:
  - `project init` (composer install, `.env` hazirlama, `key:generate`, `storage:link`)
  - opsiyonel `migrate`, `db:seed`, `npm install`, `npm run build/dev`

## Faz 5 - Multi-Webserver Parity (Apache2/Caddy)

- Apache2/Caddy adaptorlerinin eklenmesi
- Ortak registry modelinden config uretimi
- Domain/path cakisma kurallari ve override akisi

## Faz 6 - Native Service Orchestration

- Native mode servis adaptorleri
- Port intelligence (default -> fallback -> state)
- Servis install/start/stop/status ilk versiyon
- `services supported --mode=native` komutu ve dokumani
- Minimal default profile:
  - default true: php, composer, mariadb, nginx
  - diger tum servisler default false
- `services update` reconcile:
  - configte sonradan true olan servisleri algila
  - otomatik install + start et
- Servis versiyon yonetimi:
  - `services install <name> --version=<x.y.z>`
  - service bazli pinned version kaydi
- PHP multi-version:
  - birden fazla php surumu yuklenebilir/yonetilebilir
  - default `php` alias'i secilen surume baglanir
  - alternatif aliaslar (`php82`, `php83` vb.) tanimlanir
- Laravel runtime servisleri:
  - scheduler (cron/systemd timer)
  - queue worker
  - horizon (+ supervisor)
  - opsiyonel reverb/websocket ve octane process yonetimi
- Non-root operasyonlar:
  - logs, health, status, service up/down icin root zorunlu degil
- Horizon process yonetimi:
  - `supervisor` kurulum ve config publish
  - Horizon icin supervisor program template ve health check

## Faz 7 - Docker-Lite Mode

- Minimal compose/workspace modeli
- `compose up/down/status` ve health-check
- Registry ile docker-lite site publish uyumu
- `services supported --mode=docker-lite` cikti parity
- Hedef: native'deki cogunluk servis icin docker-lite parity
- Horizon calisma modeli:
  - docker-lite icinde supervisor veya esdeger process manager stratejisi
- Versiyon parity:
  - docker-lite image tag'leri ile service version secimi
  - php surum ve alias davranisinda native ile uyum
- Durum notu (2026-03-10):
  - Faz `beta-frozen` olarak kilitlendi.
  - Kalan lightweight/local+production ergonomi backlog'a alindi.

## Faz 8 - Laradock Bridge Mode

- Laradock auto-discovery
- Bridge inspect/sync
- Var olan laradock stack ile guvenli entegrasyon
- Oncelik notu (2026-03-10):
  - Aktif gelistirme odagi bu faza tasindi.
  - Hedef: native + laradock-bridge tek komut yuzeyi parity.

## Faz 9 - Observability, Ops, Production

- `doctor`, `health`, `logs`, `monitor summary`
- Log rotasyonu, durum raporu, backup/restore (site registry)
- Server install/update/upgrade operasyonlari
- TLS/certificate otomasyonu (native + docker-lite uyumlu script)
- Secrets yonetimi (env/file tabanli + policy)
- Rollback/failback mekanizmasi (config apply fail olursa geri al)
- Optional backup kapsam genisletme: config + db dump
- Pinned version + optional auto-update stratejisi
- DNS yonetimi: bu fazda degil, ileri faz icin backlog
- Production deploy akisi:
  - maintenance/zero-downtime stratejisi
  - migration safety adimlari
  - queue/horizon recycle (`queue:restart`, `horizon:terminate`)
  - post-deploy health gate ve otomatik rollback

## Faz 10 - Stabilization, Release, Adapter-Readiness

- E2E/regression matrisi (3 mod x ana senaryolar)
- CLI output contract stabilizasyonu
- `plume-adapter` projesinin hizli entegrasyonu icin full dokumantasyon tamamlama
- Full E2E zorunlulugu (smoke yeterli degil)
- Herd parity checklist + beyond feature checklist kapanis raporu

## Faz Gate Kurali

Bir fazin tamamlanma kriteri:

1. Testler gecti
2. Komut dokumanlari guncellendi
3. `implementation/05-decision-log.md` guncellendi
4. Sonraki faz riskleri yazildi
5. Ilgili faz icin Laravel project lifecycle senaryosu dogrulandi

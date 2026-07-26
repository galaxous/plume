# Target Architecture

## Tasarim Ilkeleri

- Tek binary/entrypoint: `plumectl`
- Mod bazli engine secimi: `native | docker-lite | laradock-bridge`
- Idempotent komutlar: ayni komut tekrarinda bozucu etki olmamali
- Durum farkindaligi: "kurulu mu, calisiyor mu, port bos mu" zeka katmani
- Monolitik script yok: import (`source`) ile moduler shell mimarisi

## Katmanlar

1. CLI Layer
   - Komut parse
   - Mode secimi
   - Output formatting

2. Config Layer
   - `plume.yml` okuma/dogrulama
   - Environment override
   - Secret referanslari (path/env)
   - Unified `.env` contract (`PLUME_*`) + mode-specific prefixes

3. State Layer
   - Runtime state (`~/.config/plume/state.json` benzeri)
   - Port allocation kayitlari
   - Last health-check sonuclari

4. Engine Layer
   - NativeEngine
   - DockerLiteEngine
   - LaradockBridgeEngine

5. Service Adapters
   - Her servis icin install/start/stop/status/health/logs
   - Paket yonetimi ve config dosyasi template isleri
   - Mode bazli supported-service envanteri
   - Servis bagimlilik kurallari (ornek: `horizon -> supervisor`)

6. Observability Layer
   - Health-check toplayici
   - Log toplayici/yonlendirici
   - Basit metrik ozeti

7. Platform & Prerequisite Layer
   - OS detection (macOS/Linux)
   - Linux distro detection (apt/dnf)
   - Core dependency checks + fail-fast gate

8. Site Registry Layer
   - Merkezi websites kayitlari (`site-id`, path, domain, server, mode)
   - Server-specific config render/publish akisi
   - Drift detection (registry ile sistem config farki)

9. Documentation & Contract Layer
   - Komut bazli dokumantasyon (`docs/commands/*`)
   - CLI output/exit-code sozlesmeleri (`docs/contracts/*`)
   - Her release'te adapter-readiness kontrolu

10. Security, Secrets & Rollback Layer
   - TLS certificate lifecycle (issue/renew/apply)
   - Secret source resolution (env/file)
   - Config apply transaction + rollback
   - Firewall/OS security preflight checks

11. Version Resolution Layer
   - Service-specific version pin/resolution
   - PHP multi-version inventory
   - Alias/default PHP switching rules

12. Laravel Lifecycle Layer
   - Project bootstrap (`composer`, `.env`, `key:generate`, `storage:link`)
   - Runtime orchestration (`queue`, `scheduler`, `horizon`, optional `octane/reverb`)
   - Deploy orchestration (`migrate`, warmup, restart, health gate, rollback)

13. Service Reconcile Layer
   - Config diff (enabled toggles) tespiti
   - `false -> true` servisler icin auto install + auto start
   - Drift ve partial-failure retry policy

## Shell Modulerlik Sozlesmesi

Onerilen dosya yapisi:

- `bin/plumectl`: ince entrypoint, sadece bootstrap + router cagrisi
- `lib/bootstrap.sh`: strict mode, env bootstrap, import loader
- `lib/common/*.sh`: log, error, fs, process, ports
- `lib/config/*.sh`: yaml parse/validate (ileride parser baglantisi)
- `lib/commands/*.sh`: komut handler'lari (`cmd_status`, `cmd_services_up` vb.)
- `lib/engines/*.sh`: `engine_native_*`, `engine_docker_lite_*`, `engine_laradock_bridge_*`
- `lib/services/*.sh`: servis adaptorleri (`svc_mysql_*`, `svc_redis_*`)
- `lib/sites/*.sh`: site registry, prompt, server config publish, hosts sync
- `lib/docs/*.sh` (opsiyonel): doc-sync yardimci scriptleri

Import kurallari:

- Tum moduller `#!/usr/bin/env bash` ve `set -euo pipefail` uyumlu olmali
- Import sadece bootstrap uzerinden yapilmali (daginik `source` yasak)
- Fonksiyon adlari namespace ile baslamali:
  - `cmd_*`, `engine_*`, `svc_*`, `port_*`, `cfg_*`, `log_*`
- Moduller global degisken yerine acik parametre + return code kullanmali
- Komutlar test edilebilirlik icin yan etkili adimlari adaptor fonksiyonlarina deleg etmeli

## Website Onboarding Tasarimi

Hedef komutlar:

- `plumectl site add` (interactive)
- `plumectl site add --path=... --domain=... --server=nginx` (non-interactive)
- `plumectl site link <site-id>` (registry kaydini aktif server config'e yazar)
- `plumectl site check <site-id>` (path + config + port + health dogrulama)

Interactive prompt adimlari (`site add`):

1. Proje yolu sor
2. Yol gercek mi ve web root var mi kontrol et (`public/`, static root, custom root)
3. Web server secimi sor (`nginx|apache2|caddy`)
4. Domain/alias sor (`myapp.test`, `api.myapp.test`)
5. Cakisma kontrolu yap (domain ayni, path ayni, port/service down)
6. Registry kaydini yaz
7. Server config dosyasini uret ve aktif et
8. Gerekirse hosts guncelle + server reload + sonuc raporu
9. Laravel proje ise bootstrap adimlarini oner/uygula

Merkezi registry ve path cozumleme:

- CWD'den bagimsiz calisir; her site kaydi absolute path tutar
- Varsayilan registry konumu:
  - Lokal: `~/.config/plumectl/sites/`
  - Server: `/etc/plume/sites/`
- Her proje icin bir `website.yaml`, global indeks icin `index.yaml`
- Komutlar `--cwd` yerine registry'deki path'i source of truth kabul eder

## Dokumantasyon Zorunlulugu

- Her yeni komut ve flag icin `docs/commands` altinda belge zorunlu
- Davranis degisikliginde komut dokumani ve sozlesme dosyasi ayni degisiklikte guncellenmeli
- CLI ciktilari adapter tarafinda parse edilecegi icin:
  - Basarili islerde stabil alan isimleri
  - Hatali islerde stabil error code + message semasi

## Yetki Modeli (Privilege Split)

- Sudo/root zorunlu:
  - install, uninstall, update, service package install, system config write
- Root zorunlu olmayan runtime komutlari:
  - `status`, `health`, `logs`, `services up/down` (mumkun oldugunca non-root)
- Komut her zaman once yetki preflight kontrolu yapar ve eksikse net yonerge verir

## Horizon & Supervisor Kurali

- Laravel Horizon, native modda supervisor ile yonetilir.
- `horizon.enabled=true` ise:
  - `supervisor` prereq kontrolu zorunlu
  - supervisor config/template publish zorunlu
  - `plumectl services up horizon` supervisor uzerinden process acmali
- Docker-lite modda Horizon icin supervisor veya esdeger process manager stratejisi dokumante edilir.

## Secrets & TLS

- Secrets kaynaklari:
  - environment variables
  - encrypted/plain file reference (policy'ye gore)
- TLS:
  - local: self-signed/mkcert benzeri akis
  - production: ACME/letsencrypt benzeri otomasyon
  - docker-lite icin gerekirse dedicated cert-helper container

## Rollback Modeli

- Config apply adimlari transaction benzeri calisir:
  1. once backup al
  2. yeni config yaz
  3. validation/reload yap
  4. fail olursa onceki config'e otomatik don
- Rollback sonucunu log ve status katmanina yaz

## Laravel Project Lifecycle

- Bootstrap:
  - `composer install`
  - `.env` olustur/merge
  - `php artisan key:generate`
  - `php artisan storage:link`
  - opsiyonel: `php artisan migrate --force`, `db:seed`, `config:cache`, `route:cache`
- Runtime:
  - scheduler: cron/systemd timer
  - queue worker: supervisor/system service
  - horizon: supervisor zorunlu
  - optional: octane/reverb process manager entegrasyonu
- Deploy:
  - preflight checks
  - code/artifact switch
  - migration gate
  - queue/horizon recycle
  - post-deploy health verification
  - fail durumunda rollback

## OS Ayrimi ve Prereq Gate

Platform fonksiyonlari:

- `platform_detect_os` -> `macos | linux`
- `platform_detect_pkg_manager` -> `brew | apt | dnf | unknown`
- `platform_detect_init` -> `launchd | systemd | unknown`

Core prereq politikasi:

- Her komut execution'dan once ilgili profile gore prereq kontrolu yapar
- Eksik zorunlu bagimlilik varsa komut `non-zero` ile durur
- Ciktida su verilir:
  - eksik paket listesi
  - otomatik/manuel kurulum komut onerisi (OS'e gore)
  - "yeniden dene" adimi

Ornek prereq profilleri:

- `base`: bash, sed, awk, grep, cut, xargs, tar, gzip, curl
- `native-install`: base + sudo + package-manager(brew/apt/dnf)
- `git-ops`: base + git + ssh
- `docker-lite`: base + docker + docker compose
- `laradock-bridge`: docker-lite + existing laradock path validation

## Environment Contract

- Tum ayarlar `.env` ve yaml'den birlikte cozulur.
- Oncelik:
  1. CLI flags
  2. `.env` (`PLUME_*`)
  3. yaml config
  4. built-in defaults
- Mode-ozel prefixler:
  - native: `PLUME_NATIVE_*`
  - docker-lite: `PLUME_DOCKER_LITE_*`
  - laradock-bridge: `PLUME_LARADOCK_*`

## Service Versioning & PHP Alias

- Her servis icin versiyon secimi desteklenir (ornek: mysql 8.0, redis 7, mariadb 11).
- Version secimi precedence:
  1. CLI `--version`
  2. project yaml
  3. global default
- PHP icin:
  - Birden fazla surum birlikte bulunabilir
  - `php` default alias'i aktif surume isaret eder
  - versioned aliaslar (`php81`, `php82`, `php83`) olusturulur
  - Composer ve PHP-FPM binding'i secilen aktif surumle uyumlu olur

## Service Default Profile & Reconcile

- Varsayilan profil: `minimal-default`
  - enabled: nginx(web), php, composer, mariadb
  - disabled: diger tum opsiyonel servisler
- `services update` davranisi:
  1. mevcut state + config karsilastir
  2. `false -> true` servisleri bul
  3. prereq check
  4. install + start
  5. sonuclari state/log'a yaz

## Ornek Komut Agaci

- `plumectl mode use <mode>`
- `plumectl project init`
- `plumectl php list|install|use|alias`
- `plumectl services install [name|all]`
- `plumectl services up [name|all]`
- `plumectl services down [name|all]`
- `plumectl services supported [--mode=...]`
- `plumectl status`
- `plumectl logs [service]`
- `plumectl health [service|all]`
- `plumectl doctor [--deep]`

## Port Intelligence Stratejisi

- Her servis icin oncelik listesi:
  - ornek mysql: `3306, 3307, 3308`
- Algoritma:
  - Bos port bul -> ata -> state'e yaz
  - Doluluk degisti ise yeniden reconcile et
- Cikti:
  - Kullaniciya deterministic rapor:
    - "mysql: requested 3306, allocated 3307 (3306 occupied by process X)"

## Guvenlik ve Operasyon

- Root/sudo gereken adimlar acikca ayrilacak
- `dry-run` modu ile uygulanacak degisiklikler onceden gosterilecek
- Uretim modunda kritik adimlar confirm gate ile korunacak

## Naming Policy

- Product/brand: `Plume`
- Official CLI binary: `plumectl`
- Optional shell alias: `plume -> plumectl`
- Repository naming: `laravel-plume`
- Package naming:
  - Packagist: `<vendor>/laravel-plume`
  - Homebrew formula: `laravel-plume` veya `plumectl`

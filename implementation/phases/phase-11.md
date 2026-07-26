# Phase 11 - Native Adapter Contract Parity

## Objective

- Native mode'u, kullaniciya laradock/docker workflow hissi verecek tek-contract adapter katmanina yaklastirmak.

## Status

- `done` (started: 2026-04-03, completed: 2026-07-25)
- Priority: high

## Scope Checklist

- [x] Core parity: `php (fpm)` (baseline)
- [x] Core parity: `nginx/caddy/apache2` (baseline)
- [x] Core parity: `mariadb/mysql` (baseline)
- [x] Core parity: `phpmyadmin` (baseline)
- [x] Core parity: `laravel-horizon` (+ supervisor) (baseline)
- [x] Core parity: `redis` (baseline)
- [x] Native service contract surface (laradock-benzeri komut semantigi)
- [x] Native site lifecycle + php runtime secimi parity hardening
- [x] Native queue/horizon/supervisor operational parity
- [x] Native DB stack parity (mariadb/mysql/redis/phpmyadmin) with adapter mapping

## Implementation Checklist

- [x] Adapter alias map v2 baseline regression locked (workspace/php-fpm/horizon parity)
- [x] Native PHP matrix command surface (`php list|install|use|alias`) + persisted state
- [x] Global native env command surface (`env where|init`) + bootstrap wiring
- [x] Built-in native core env example template (`templates/native-core.env.example`)
- [x] Native service profiles (`@core/@web/@db/@queue`) laradock-equivalent behavior
- [x] Site add/update/publish icin php runtime resolve contract stabilization
- [x] Horizon lifecycle wrapper (start/stop/status/logs) with supervisor dependency clarity
- [x] PMA engine routing (`PMA_DB_ENGINE`) native UX hardening

## Test Checklist

- [x] Native adapter contract smoke (new phase11 test pack)
- [x] Native core services parity smoke (phase11 core set)
- [x] Native php default/custom version matrix smoke
- [x] Services php alias target regression (`php84`/`php-fpm-8.4` -> php@version)
- [x] Host php version shim regression (`php8.4` / `php-fpm-8.4` executable wrappers)
- [x] Mode switch safety regression (laradock-bridge -> native auto-down guard)
- [x] Site + php version routing regression (native)
- [x] Horizon/supervisor dependency + lifecycle regression
- [x] DB + phpmyadmin operational path regression

## Documentation Checklist

- [x] `docs/contracts/cli-output-contract.md` native adapter contract extension
- [x] `docs/commands/services.md` native contract examples update
- [x] `docs/commands/site.md` native php/runtime parity update
- [x] `docs/commands/global.md` env autoload/bootstrap behavior update
- [x] `docs/operations/laravel-project-lifecycle.md` native-first adapter workflow update
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-04-03
- Owner:
- Related PR/Commit:
- Progress:
  - `tests/phase11_native_adapter_contract_smoke.sh` eklendi.
  - `tests/phase11_native_core_services_parity_smoke.sh` eklendi ve gecti.
  - `tests/phase11_native_php_matrix_smoke.sh` eklendi ve gecti.
  - `tests/phase11_mode_switch_laradock_down_smoke.sh` eklendi ve gecti.
  - `php` komut ailesi aktif edildi (`list|install|use|alias list|alias set|alias default`).
  - Native PHP default/custom surum konfigurasyonu state dosyasina kalici yaziliyor (`php.env`).
  - `env` komut ailesi eklendi (`env where|init`) ve global native env path yonetimi netlesti.
  - Built-in native core env template eklendi (`templates/native-core.env.example`).
  - `mode use ... --down-running` ile laradock-bridge'ten native'e geciste calisan compose servisleri kontrollu sekilde `down` edilebiliyor.
  - Native/global env modeli aktif: varsayilan env `~/.config/plume/.env`, otomatik bootstrap destekli.
  - Services contract'ta PHP target alias resolve genisletildi:
    - `services up php84`, `services status php-fpm-8.4`, `services health php82`, `services logs php84`
    - hepsi canonical `php` service + hedef PHP version resolve ile calisiyor.
  - Yeni regression testi eklendi ve gecti:
    - `tests/phase11_services_php_alias_target_smoke.sh`
  - `plume_load_env` dis env oneceligini koruyacak sekilde guncellendi:
    - komut satirindan verilen `PLUME_*`/`PMA_*` degerleri global env tarafindan ezilmiyor.
  - Host php shim komutlari eklendi:
    - `php shim install|env|list|remove`
    - `php8.4` ve `php-fpm-8.4` gibi executable shim dosyalari uretilip PATH'e eklenebiliyor.
  - Shell bootstrap komutu eklendi:
    - `init shell [--shell=zsh|bash] [--rc=...] [--force]`
    - rc dosyasina plume shim aktivasyon blogunu idempotent sekilde yazar.
  - `php shim env` genisletildi:
    - default disi tum kurulu PHP versiyonlari icin shell alias export eder (`php81`, `phpfpm81`).
  - Doctor komutu genisletildi:
    - `doctor php [--strict]` ile configured PHP matrix icin cli/fpm binary bulunurlugu raporlanir.
    - `--strict` modunda eksik binary varsa `exit 2`.
  - Native `services install php` gercek host binary provisioning'e baglandi:
    - install driver: `brew|apt` (dnf su an manual yonlendirme)
    - kurulum sonrasi cli/fpm binary verify + php matrix state auto-register.
  - Native `services up php` auto-provision davranisi eklendi:
    - hedef surum matrix/binary tarafinda hazir degilse install+verify+register otomatik calisir.
  - PHP extension matrix eklendi:
    - `PLUME_PHP_EXTENSIONS_GLOBAL` + `PLUME_PHP_EXTENSIONS_<major><minor>`
    - `php ext sync <version|all>` ve `php ext doctor --strict`
    - `services up php` sirasinda extension auto-sync (`PLUME_PHP_EXTENSIONS_AUTO_SYNC=true`)
  - Doctor genisletmesi:
    - `doctor php-ext --strict`
  - Yeni test eklendi ve gecti:
    - `tests/phase11_php_shim_smoke.sh`
    - `tests/phase11_init_shell_smoke.sh`
    - `tests/phase11_php_shell_alias_export_smoke.sh`
    - `tests/phase11_doctor_php_smoke.sh`
    - `tests/phase11_doctor_web_smoke.sh`
    - `tests/phase11_services_web_sync_config_smoke.sh`
    - `tests/phase11_services_install_php_native_smoke.sh`
    - `tests/phase11_services_up_php_native_autoprovision_smoke.sh`
    - `tests/phase11_php_ext_sync_smoke.sh`
    - `tests/phase11_doctor_php_ext_smoke.sh`
    - `tests/phase11_services_up_php_ext_autosync_smoke.sh`
    - `tests/phase11_site_reload_validate_smoke.sh`
    - `tests/phase11_site_nginx_strict_publish_smoke.sh`
    - `tests/phase11_site_nginx_strict_missing_include_smoke.sh`
    - `tests/phase11_site_php_upstream_override_smoke.sh`
    - `tests/phase11_site_nginx_strict_no_double_reload_smoke.sh`
    - `tests/phase11_site_nginx_php_front_controller_smoke.sh`
    - `tests/phase11_site_apache2_caddy_strict_publish_smoke.sh`
    - `tests/phase11_php_ext_resolve_contract_smoke.sh`
    - `tests/phase11_php_ext_toggle_disable_precedence_smoke.sh`
    - `tests/phase11_site_check_strict_visibility_smoke.sh`
  - Core parity onceligi 6 servis setine kilitlendi:
    - `php(fpm)`, `nginx/caddy/apache2`, `mariadb/mysql`, `phpmyadmin`, `laravel-horizon`, `redis`
  - Native alias contract regressioni kilitlendi:
    - `php-fpm -> php`
    - `workspace -> composer`
    - `laravel-horizon -> horizon` (supervisor guard ile)
  - Web server publish guvenilirligi guclendirildi:
    - Native `site publish --reload` akisina config test asamasi eklendi (`PLUME_SITE_RELOAD_VALIDATE=true` default).
    - Geçersiz config'te reload atlanir, `PLUME_SITE_RELOAD_REQUIRED=true` ise publish fail-fast doner.
    - Native nginx strict pipeline eklendi (`PLUME_SITE_NGINX_STRICT=true`):
      - gercek include path sync (`PLUME_NGINX_INCLUDE_DIR` override veya auto-detect),
      - lint (`nginx -t`) + reload zorunlulugu,
      - fail durumunda include rollback.
      - `site publish --reload` ile strict birlikte kullanildiginda duplicate reload engellendi.
      - Strict pipeline nginx disinda apache2 ve caddy icin de eklendi (include sync + lint + reload + rollback).
  - Site bazli PHP upstream override eklendi:
    - `site add/update --php-upstream=<host:port|unix:/sock>`
    - Site kaydinda `php_upstream` saklanir; snippet render'da resolver yerine oncelikli kullanilir.
    - `site check` ciktisinda `php_upstream` ve `php_upstream_resolved` alanlari gorunur.
    - `site check` ciktisina strict publish gorunurlugu eklendi:
      - `mode`, `strict_enabled`, `strict_include_dir`, `strict_include_target`
  - PHP extension contract hibrit modele tasindi:
    - preset (`PLUME_PHP_EXT_PRESET`, `PLUME_PHP_EXT_PRESET_<ver>`)
    - toggle (`PLUME_PHP_EXT_ENABLE_*`, `PLUME_PHP_EXT_DISABLE_*`)
    - matrix (`PLUME_PHP_EXTENSIONS_GLOBAL`, `PLUME_PHP_EXTENSIONS_<ver>`)
    - resolve komutu: `php ext resolve <version|all>`
  - Native service contract yüzeyi tamamlandi:
    - service group davranislari: `@core`, `@web`, `@db`, `@queue`
    - site runtime resolve + `php_upstream` contract'i
    - `horizon` / `supervisor` dependency guard ve lifecycle wrapper
    - `PMA_DB_ENGINE` bazli `phpmyadmin` engine routing
  - Native parity regression pack tamamladi:
    - `tests/phase11_native_core_services_parity_smoke.sh`
    - `tests/phase11_native_adapter_contract_smoke.sh`
- Open risks:
  - Native gercek OS service manager farkliliklari (launchd/systemd) tek semantik altinda normalize edilirken edge-case riski.
  - Horizon/supervisor lifecycle'inda process ownership/permission drift riski.
  - Native ve laradock-bridge cikti kontrati farklari adapter parse katmaninda kirilma yaratabilir.

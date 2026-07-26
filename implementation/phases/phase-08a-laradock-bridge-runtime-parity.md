# Phase 08A - Laradock Bridge Runtime Parity

## Objective

- `laradock-bridge` modunda mevcut Laradock stack'lerini Plume'in standart service komut yuzeyi ile guvenli sekilde yonetmek.
- Hedef: `native` ile ayni komut contract'ini korurken engine tarafinda Laradock compose/container durumuna baglanmak.

## Delivery Scope

Bu alt faz sadece ilk runtime parity dilimini kapsar.
Asagidaki komutlar gercek Laradock runtime'a baglanacak:

- `services up <service>|all --mode=laradock-bridge`
- `services down <service>|all --mode=laradock-bridge`
- `services status [--mode=laradock-bridge]`
- `services health [service] --mode=laradock-bridge`
- `services logs <service> --mode=laradock-bridge`
- `services exec <service> --mode=laradock-bridge`
- `services containers [service] --mode=laradock-bridge`

## Non-Goals

- Laradock repo icini plume'nin yeniden tasarlamasi
- Yeni compose template olusturma
- Docker-lite parity genisletmesi
- Native host provisioning
- TLS, secrets, backup, rollback production akislari

## Runtime Source of Truth

- `laradock-bridge` icin birincil source-of-truth canli docker compose/container durumudur.
- State env dosyalari ve SQLite yalnizca cache/telemetry amaclidir.
- Live docker ile state cakisirse, live docker kazanir.

## Service Mapping Baseline

Ilk dilimde asagidaki service map standardize edilir:

| Plume Service | Laradock Compose Service |
|---|---|
| `nginx` | `nginx` |
| `apache2` | `apache2` |
| `caddy` | `caddy` |
| `php` / `php-fpm` | `php-fpm` |
| `workspace` | `workspace` |
| `composer` | `workspace` |
| `mariadb` | `mariadb` |
| `mysql` | `mysql` |
| `phpmyadmin` | `phpmyadmin` |
| `redis` | `redis` |
| `horizon` | `laravel-horizon` |
| `supervisor` | `laravel-horizon` |
| `php-worker` | `php-worker` |

Not:

- Bu dilimde `supervisor`, Laradock tarafinda ayrik container olarak degil `laravel-horizon` icindeki process manager davranisi olarak modellenir.
- `composer` ayrik container degil, `workspace` alias'i olarak kalir.

## Implementation Plan

### 1. Compose Discovery Normalization

- `mode path get laradock-bridge` + `--path` + env override zinciri tek yerde normalize edilecek.
- Compose file cozumleme Laradock icin deterministic hale getirilecek.
- `COMPOSE_PROJECT_NAME` ve container isimleri dogrudan `.env` + compose uzerinden cozumlenecek.

### 2. Runtime Lifecycle

- `services up/down` Laradock compose service map'i ile gercek `docker compose up -d/stop` calistiracak.
- `all` davranisi destructive olmayacak:
  - sadece Plume destek matrisindeki hedef servisleri etkileyecek
  - Laradock'taki bilinmeyen servisleri hedeflemeyecek

### 3. Status/Health/Logs

- `status`:
  - live container state okunacak
  - `enabled/running/health/port/version` normalize edilecek
- `health`:
  - container running + healthcheck state okunacak
  - healthcheck yoksa `running=true -> healthy`, degilse `stopped`
- `logs`:
  - `docker compose logs --tail N`
- Her okuma sonunda SQLite `services` tablosu cache olarak guncellenecek.

### 4. Exec/Containers Hardening

- Mevcut `exec` ve `containers` komutlari Laradock path normalization ile sertlestirilecek.
- `composer` -> `workspace` alias'i korunacak.
- `native` modda block davranisi degismeyecek.

### 5. Safe Interoperability

- `services up/down` once `services laradock check` benzeri minimal preflight yapacak.
- Path/compose bulunamazsa fail-fast donecek.
- Bilinmeyen service mapping'lerde fallback yerine explicit error donulecek.

## Test Plan

### Required Smokes

- `phase8_laradock_runtime_status_smoke.sh`
- `phase8_laradock_runtime_health_logs_smoke.sh`
- `phase8_laradock_runtime_up_down_smoke.sh`
- `phase8_laradock_runtime_exec_containers_smoke.sh`
- `phase8_laradock_runtime_sync_db_smoke.sh`

### Regression Gates

- mevcut `phase8_laradock_bootstrap_smoke.sh`
- mevcut `phase7_services_exec_smoke.sh`
- mevcut `phase7_services_containers_smoke.sh`
- native service smoke'lar kirilmamali

## Definition of Done

- `laradock-bridge` modunda `up/down/status/health/logs/exec/containers` komutlari canli Laradock compose durumuna baglanir
- state DB cache senkron kalir
- unsupported/destructive davranis default olarak yapilmaz
- docs guncellenir
- decision log eklenir

## Risks

- Laradock compose varyasyonlari (`docker-compose.override`, custom compose file zinciri)
- `COMPOSE_PROJECT_NAME` farkliliklari nedeniyle container isimlerinin beklenenden sapmasi
- `laravel-horizon`/`php-worker` image veya service isimlerinin repo fork'larinda degisebilmesi

## Immediate Next Step

- Once `status/health/logs` uygulanmali.
- Ardindan `up/down`.
- En sonda `exec/containers` normalization + DB sync sertlestirmesi.

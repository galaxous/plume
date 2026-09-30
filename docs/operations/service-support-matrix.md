# Service Support Matrix

Bu dosya `native` ve `docker-lite` modlarinda hangi servislerin desteklendigini tek noktada gosterir.

Komutla sorgulama:

```bash
plumectl services supported
plumectl services supported --mode=native
plumectl services supported --mode=docker-lite
```

## Matrix

| Service     | native | docker-lite | laradock-bridge | Notes |
|-------------|--------|-------------|-----------------|-------|
| nginx       | yes    | yes         | yes             | web server |
| apache2     | yes    | no          | opt             | laradock compose'ta varsa |
| caddy       | yes    | yes         | opt             | laradock compose'ta varsa |
| php-fpm     | yes    | yes         | yes             | php runtime |
| composer    | yes    | yes         | yes             | tool/runtime support |
| xdebug      | opt    | opt         | opt              | optional profile |
| mysql       | yes    | yes         | yes             | database |
| mariadb     | yes    | yes         | yes             | database |
| phpmyadmin  | yes    | yes         | yes             | PMA_DB_ENGINE ile mysql/mariadb secimi |
| postgres    | yes    | yes         | opt             | laradock compose'ta varsa |
| pgadmin     | yes    | opt         | opt             | Laradock pgadmin parity; postgres gerektirir |
| redis       | yes    | yes         | yes             | cache/queue |
| memcached   | yes    | no          | opt             | native brew/apt (D-145); laradock compose'ta varsa |
| rabbitmq    | yes    | no          | opt             | laradock compose'ta varsa |
| mongodb     | yes    | opt         | opt             | laradock compose'ta varsa |
| mongo-webui | yes    | opt         | opt             | laradock compose'ta varsa |
| mailpit     | yes    | yes         | opt             | native: macOS brew; Linux docker-lite |
| meilisearch | opt    | opt         | opt              | native toggle-only (D-146); driver backlog |
| minio       | opt    | yes         | opt             | native toggle-only (D-146); laradock compose'ta varsa |
| supervisor  | yes    | opt         | yes             | system brew/systemd + program registry (D-149) |
| horizon     | yes    | yes         | yes             | native: `php artisan horizon` + supervisor gate |
| php-worker  | yes    | yes         | yes             | native: registry-only; queue worker |

Laradock-bridge note:

- Bu matris Laradock icin minimum beklenen baseline'i gosterir.
- Gercek runtime'ta `laradock-bridge`, aktif Laradock `docker-compose.yml` dosyasindaki tum servisleri discover edip gosterebilir/yonetebilir.
- Yani Laradock kolonu static minimum capability'dir; runtime service listesi compose dosyasindan gelir.

## Durum Etiketleri

- `yes`: destekli
- `no`: desteklenmiyor
- `opt`: opsiyonel/profile bazli

## Default Toggle Policy

- Minimal default profile'ta yalnizca su servisler default `true`:
  - nginx(web)
  - php runtime
  - composer
  - mariadb
- Diger servisler default `false` olup ihtiyaca gore sonradan acilir.
- `services update` ile sonradan `true` olan servisler otomatik reconcile edilir.

## Versioning

- Her servis icin opsiyonel `PLUME_<SERVICE>_VERSION` env degeri desteklenir.
- `services status/supported --json` komutlarinda her servis icin aktif surum bilgisi gosterilir.
- PHP servisleri icin alias cozumlemesi desteklenir (`php`, `default`, alias adlari).

## Phase 6 Native Runtime

- Native mode icin `services install/up/down/status/health/logs` command-path'leri calisir.
- Port kullanan servislerde fallback port secimi uygulanir:
  - default port doluysa `+1..+50` araliginda bos port aranir.
  - secilen port `services_ports_native.env` state dosyasina yazilir.
- Runtime state (`running`, `health`) `services_runtime_native.env` dosyasinda tutulur.

## Phase 7 Docker-Lite Runtime

- Docker-lite mode icin `services install/up/down/status/health/logs` command-path'leri compose-service eslemesi ile calisir.
- `services workspace up|down|status --mode=docker-lite` komutlari compose workspace lifecycle'ini yonetir.
- Docker-lite runtime state/port metadata dosyalari native ile ayni formatta tutulur.
- 2026-03-10 notu: docker-lite `beta-frozen` durumundadir; aktif gelistirme onceligi native + laradock-bridge parity'sine kaydirilmistir.

## Kural

- Yeni servis eklendiginde bu matris ve `services supported` komut dokumani ayni degisiklikte guncellenir.
- Service custom version destegi aktif oldugunda, desteklenen major/minor araliklar da bu dosyada belirtilir.

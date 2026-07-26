# Environment Contract

Plume ayarlari `.env` uzerinden yonetilebilir.

## Ortak Kural

- Ortak degisken prefixi: `PLUME_`
- Varsayilan ornek dosya: `.env.example`
- Degiskenler mode fark etmeden ayni isimlendirme standardini kullanir.
- Varsayilan config dosyasi: `plume.yml` (proje-local site manifest)
- Native stack manifest: `~/.config/plume/services.yml` — birlesme sirasi: defaults → `services.yml` → `~/.config/plume/.env` (env kazanir). Bkz. [services-manifest.md](./services-manifest.md)

## Mode-Ozel Prefixler

- Native: `PLUME_NATIVE_*`
- Docker-lite: `PLUME_DOCKER_LITE_*`
- Laradock-bridge: `PLUME_LARADOCK_*`

Not:

- Native ve docker-lite icin birincil config kaynagi ortak `PLUME_*` degiskenleridir.
- `PLUME_DOCKER_LITE_*` degiskenleri adapter-level override ve service-name mapping amacli kullanilir.

## Default Toggle Policy

- Default `true`: `nginx`, `php`, `composer`, `mariadb`
- Diger servisler default `false`
- Sonradan `false -> true` olanlar `services update` ile reconcile edilir.

## Site/Adapter Degiskenleri

- `PLUME_SITE_HOSTS_SYNC=true|false`: publish/remove sırasında hosts dosyasi guncellemesini acar/kapatir.
- `PLUME_SITE_HOSTS_REQUIRED=true|false`: hosts yazimi basarisizsa komutun fail edip etmeyecegini belirler.
- `PLUME_SITE_RELOAD_REQUIRED=true|false`: `site publish --reload` basarisizsa komutun fail edip etmeyecegini belirler.
- `PLUME_SITE_RELOAD_VALIDATE=true|false`: native reload oncesi config test (`nginx -t`, `apachectl/httpd -t`, `caddy validate`) yapilip yapilmayacagini belirler.
- `PLUME_SITE_NGINX_STRICT=true|false`: native nginx publish'te hedef include path + lint + reload pipeline'i zorunlu kilar.
- `PLUME_NGINX_INCLUDE_DIR=/path/to/include`: native nginx strict publish hedef include dizinini explicit belirler.
- `PLUME_SITE_APACHE2_STRICT=true|false`: native apache2 publish'te include path + lint + reload pipeline'i zorunlu kilar.
- `PLUME_APACHE2_INCLUDE_DIR=/path/to/include`: native apache2 strict publish hedef include dizinini explicit belirler.
- `PLUME_SITE_CADDY_STRICT=true|false`: native caddy publish'te include path + lint + reload pipeline'i zorunlu kilar.
- `PLUME_CADDY_INCLUDE_DIR=/path/to/include`: native caddy strict publish hedef include dizinini explicit belirler.
- `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true|false`: docker-lite publish/reload once compose dosyasi zorunlulugu.
- `PLUME_DOCKER_LITE_*_SERVICE=<compose-service-name>`: servis-adi -> compose servis esleme override (ornek: `PLUME_DOCKER_LITE_REDIS_SERVICE=redis-cache`).
- `PLUME_PHP_VERSION`: docker-lite default `php-fpm` image tag kaynagi.
- PHP extension matrix:
  - `PLUME_PHP_EXT_PRESET=none|laravel-core|queue|media|full`
  - `PLUME_PHP_EXT_PRESET_81`, `PLUME_PHP_EXT_PRESET_82`, ...
  - `PLUME_PHP_EXTENSIONS_GLOBAL`
  - `PLUME_PHP_EXTENSIONS_81`, `PLUME_PHP_EXTENSIONS_82`, ...
  - `PLUME_PHP_EXT_ENABLE_<EXT>=true|false`
  - `PLUME_PHP_EXT_ENABLE_<VER>_<EXT>=true|false` (ornek: `PLUME_PHP_EXT_ENABLE_84_XDEBUG=true`)
  - `PLUME_PHP_EXT_DISABLE_<VER>_<EXT>=true|false`
  - `PLUME_PHP_EXTENSIONS_STRICT=true|false`
  - `PLUME_PHP_EXTENSIONS_AUTO_SYNC=true|false`
  - `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=matrix|target|default`
  - `PLUME_PHP_EXT_INSTALL_DRIVER=brew|apt|mock|...`
- Native per-version php-fpm upstream override:
  - `PLUME_NATIVE_PHP_FPM_UPSTREAM` (default php)
  - `PLUME_NATIVE_PHP_FPM_UPSTREAM_81`, `..._82`, `..._84`
- `PLUME_NATIVE_HOST_PROVISION=true|false`: native modda `web`, `mariadb`, `mysql`, `redis` (ve apache2 driver) icin gercek host paket kurulum/start/stop. Varsayilan `false` (state simulate).
- `PLUME_NONINTERACTIVE=true|false`: macOS permission menu ve TTY brew/sudo onaylarini atla (CI; global `--yes` ile uyumlu).
- `PLUME_INTERACTIVE=true|false`: TTY disinda veya icinde interaktif prompt davranisi (bkz. `docs/operations/macos-permissions.md`).
- `PLUME_SITE_AUTO_PROVISION_WEB=true|false`: native `site publish --reload` sirasinda web sunucusu yoksa otomatik host kurulum/baslatma. Varsayilan `true`.
- Native Homebrew nginx ana config port yonetimi:
  - `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true|false`: `services web sync-config` / `doctor web fix-ports` ile ana `nginx.conf` listen patch (varsayilan `false`).
  - `PLUME_NATIVE_NGINX_HTTP_PORT`: hedef HTTP port (varsayilan `80`).
  - `PLUME_NATIVE_NGINX_MAIN_CONF`: ana nginx config dosya yolu override.
  - `PLUME_NATIVE_HOMEBREW_HTTP_PORT`: site `port: 80` renderinda effective port zorlamasi (orn. `8080`; ana config 80 olsa bile override eder).
- `PLUME_WEB_SERVER_VERSION`, `PLUME_MARIADB_VERSION`, `PLUME_MYSQL_VERSION`, `PLUME_POSTGRES_VERSION`, `PLUME_REDIS_VERSION`: docker-lite image taglerinde birincil kaynaktir.
- `PLUME_DOCKER_LITE_PHP_FPM_IMAGE=php:<ver>-fpm-alpine`: default php-fpm image override (opsiyonel).
- `PLUME_LARADOCK_STRICT=true|false`: laradock-bridge publish/reload icin strict path+compose+container preflight.
- `PLUME_LARADOCK_COMPOSE_FILE=/abs/path/docker-compose.yml`: laradock-bridge compose dosya yolu override.

Laradock path policy:

- Laradock path `.env` ile yonetilmez.
- Birincil kaynak:
  - `--path=<laradock-dir>` gecici override
  - veya `mode path set laradock-bridge <laradock-dir>` ile kayitli global state
- Runtime Laradock komutlari path tahmin etmez; gecerli bir Laradock path yoksa fail-fast olur.

## Runtime State Dosyalari

- Native:
  - `PLUME_STATE_DIR/services_runtime_native.env`
  - `PLUME_STATE_DIR/services_ports_native.env`
- Docker-lite:
  - `PLUME_STATE_DIR/services_runtime_docker-lite.env`
  - `PLUME_STATE_DIR/services_ports_docker-lite.env`
- SQLite mirror (phase start):
  - `PLUME_STATE_DB_FILE` (varsayilan: `PLUME_STATE_DIR/plume-state.db`)
  - tablolar: `services`, `runtime_events`, `locks`

## Oncelik Sirasi

1. CLI flags
2. Global state (`mode use`, `mode path set`)
3. `.env` (mode/path haric)
4. YAML config
5. Built-in defaults

Not:

- `.env` icindeki `PLUME_MODE`, `PLUME_DOCKER_LITE_COMPOSE_FILE`, `PLUME_LARADOCK_PATH` degerleri uygulanmaz.

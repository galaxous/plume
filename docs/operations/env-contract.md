# Environment Contract

Plume ayarlari `.env` uzerinden yonetilebilir.

## Ortak Kural

- Plume-özel degisken prefixi: `PLUME_` (state, mode, site, native driver ayarlari)
- Stack servis toggle/port/credential: **Laradock-style kisa isimler** (ornek `REDIS_ENABLED`, `MARIADB_PORT`) — canonical config dosyalarinda (D-130)
- Varsayilan ornek dosya: `.env.example`
- Degiskenler mode fark etmeden ayni isimlendirme standardini kullanir.
- Varsayilan config dosyasi: `plume.yml` (proje-local site manifest)
- Native stack manifest: `~/.config/plume/services.yml` — birlesme sirasi: defaults → `services.yml` (`${REDIS_ENABLED}` vb. cozulur) → `~/.config/plume/.env` (env kazanir). Bkz. [services-manifest.md](./services-manifest.md)

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
  - `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=matrix|target|default` — gunluk macOS dev icin `target` onerilir (`docs/operations/local-dev-macos.md`)
  - `PLUME_PHP_EXT_INSTALL_DRIVER=brew|apt|mock|...`
- Native per-version php-fpm upstream override:
  - `PLUME_NATIVE_PHP_FPM_UPSTREAM` (default php)
  - `PLUME_NATIVE_PHP_FPM_UPSTREAM_81`, `..._82`, `..._84`
- `PLUME_NATIVE_HOST_PROVISION=true|false`: native modda `web`, `mariadb`, `mysql`, `redis` (ve apache2 driver) icin gercek host paket kurulum/start/stop. Varsayilan `false` (state simulate).
- `PLUME_NONINTERACTIVE=true|false`: macOS permission menu ve TTY brew/sudo onaylarini atla (CI; global `--yes` ile uyumlu). Native MariaDB/MySQL root sifre bootstrap sifresiz TCP denemesi yapmaz (tty `Password:` prompt yok; D-134). Hosts sync `sudo -n` kullanir (interaktif sudo Password yok; D-136).
- `PLUME_NATIVE_DB_HOSTS_SYNC=true|false`: native mariadb/mysql up sonrasi `/etc/hosts` alias sync (varsayilan `true`; smoke/CI: `false`).
- `PLUME_INTERACTIVE=true|false`: TTY disinda veya icinde interaktif prompt davranisi (bkz. `docs/operations/macos-permissions.md`).
- `PLUME_SITE_AUTO_PROVISION_WEB=true|false`: native `site publish --reload` sirasinda web sunucusu yoksa otomatik host kurulum/baslatma. Varsayilan `true`.
- Native Homebrew nginx ana config port yonetimi:
  - `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true|false`: ana `nginx.conf` listen yonetimi (varsayilan `true`, D-151).
  - `PLUME_NATIVE_NGINX_HTTP_PORT`: hedef HTTP port (varsayilan `80` — portsuz `http://site.test`).
  - `PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH` / `PLUME_NATIVE_NGINX_ENSURE_ON_WEB_UP`: otomatik ensure (varsayilan `true`).
  - `plumectl services web ensure`: sync + elevated bind + site republish.
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

## Stack Service Env (Laradock mapping)

Stack servis toggle/port/credential ayarlari `.env` ve `services.yml` icinde **Laradock-style kisa isimlerle** yazilir. Runtime icinde `plume_env_apply_laradock_aliases_*` (`lib/common/stack_service_env.sh`) senkronize eder:

1. **outward** (defaults sonrasi, manifest oncesi): `PLUME_*` → kisa isim (yalnizca kisa isim bosken; `${REDIS_ENABLED}` interpolation)
2. **refresh** (manifest sonrasi): manifest'in guncelledigi `PLUME_*` → kisa isim (her zaman)
3. **inward** (`.env` sonrasi): kisa isim → `PLUME_*` (`.env` / CLI kisa isim kazanir)

Env yukleme (`plume_load_env`): dosya alias ciftinin yalnizca bir ucunu tanimliyorsa (ornek `PLUME_REDIS_ENABLED=true`), eslestirilen kisa isim defaults/manifest oncesi deger olarak korunmaz; source sonrasi yalnizca `PLUME_*` varsa kisa isim buna senkronize edilir (D-131).

Yalnizca `PLUME_*` (eski stil) hâlâ calisir; deprecated.

| Laradock (canonical) | Internal (`PLUME_*`) | Varsayilan |
|-------|------------------|------------|
| `REDIS_ENABLED` | `PLUME_REDIS_ENABLED` | `false` |
| `MARIADB_ENABLED` | `PLUME_MARIADB_ENABLED` | `true` |
| `MYSQL_ENABLED` | `PLUME_MYSQL_ENABLED` | `false` |
| `PHPMYADMIN_ENABLED` | `PLUME_PHPMYADMIN_ENABLED` | `false` |
| `POSTGRES_ENABLED` | `PLUME_POSTGRES_ENABLED` | `false` |
| `REDIS_PORT` | `PLUME_REDIS_PORT` | `6379` |
| `REDIS_PASSWORD` | `PLUME_REDIS_PASSWORD` | `secret_redis` |
| `MONGODB_PORT` | `PLUME_MONGODB_PORT` | `27017` |
| `MONGO_USERNAME` | `PLUME_MONGODB_USERNAME` | `root` |
| `MONGO_PASSWORD` | `PLUME_MONGODB_PASSWORD` | `example` |
| `PLUME_MONGODB_DATABASE` | — | `admin` |
| `RABBITMQ_NODE_HOST_PORT` | `PLUME_RABBITMQ_PORT` | `5672` |
| `RABBITMQ_MANAGEMENT_HTTP_HOST_PORT` | `PLUME_RABBITMQ_MANAGEMENT_PORT` | `15672` |
| `RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` | `PLUME_RABBITMQ_USER` / `PASSWORD` | `guest` / `guest` |
| `MONGO_WEBUI_PORT` | `PLUME_MONGO_WEBUI_PORT` | `8082` (Plume; Laradock often `3000`) |
| `PLUME_MONGO_WEBUI_URI` | `MONGO_WEBUI_MONGO_URL` | otomatik (`mongodb://user:pass@127.0.0.1:27017/admin`) |
| `PLUME_MONGO_WEBUI_USERNAME` / `PASSWORD` | mongo-express basic auth | `admin` / `pass` |
| `REDIS_WEBUI_PORT` | `PLUME_REDIS_WEBUI_PORT` | `8083` (Plume; Laradock often `9987`) |
| `REDIS_WEBUI_USERNAME` / `PASSWORD` | `PLUME_REDIS_WEBUI_USERNAME` / `PASSWORD` | `laradock` / `laradock` |
| `REDIS_WEBUI_CONNECT_HOST` / `REDIS_WEBUI_CONNECT_PORT` | `PLUME_REDIS_WEBUI_HOST` / `REDIS_PORT` | `127.0.0.1` / `6379` |
| `MEMCACHED_ENABLED` / `MEMCACHED_PORT` | `PLUME_MEMCACHED_*` | `false` / `11211` |
| `MAILPIT_ENABLED` / `MAILPIT_PORT` / `MAILPIT_SMTP_PORT` | `PLUME_MAILPIT_*` | `false` / `8025` / `1025` |
| `SUPERVISOR_ENABLED` / `HORIZON_ENABLED` | `PLUME_SUPERVISOR_ENABLED` / `PLUME_HORIZON_ENABLED` | `false` |
| `PLUME_HORIZON_PATH` | Legacy tek-program fallback (artisan yolu) | boş → horizon-enabled siteler; yoksa ilk site/cwd |
| `PLUME_HORIZON_REQUIRE_SUPERVISOR` | `up horizon` supervisor ister | `true` |
| `PLUME_NATIVE_SUPERVISOR_MAIN_CONF` | Ana supervisord.conf override (smoke) | otomatik |
| `PLUME_NATIVE_SUPERVISOR_PROGRAMS_DIR` | Program drop-in override (smoke) | otomatik |

Degisiklik sonrasi runtime: `services restart <svc> --mode=native` veya `services env set ... --restart`. Redis icin ayrica `services redis sync-config --reload`. Bkz. [services-env.md](../commands/services-env.md), [services-redis.md](../commands/services-redis.md).

Native Redis config yonetimi (`PLUME_NATIVE_REDIS_MANAGE_CONFIG=true`, varsayilan): Plume `state/native/redis/plume-redis.conf` uretir ve system `redis.conf` icine `include` ekler.

Native DB/broker config (`PLUME_NATIVE_MARIADB_MANAGE_CONFIG`, `PLUME_NATIVE_POSTGRES_MANAGE_CONFIG`, `PLUME_NATIVE_MONGODB_MANAGE_CONFIG`, `PLUME_NATIVE_RABBITMQ_MANAGE_CONFIG`, varsayilan `true`):

| Laradock (canonical) | Internal (`PLUME_*`) | Varsayilan |
|-------|----------|------------|
| `MARIADB_PORT` | `PLUME_MARIADB_PORT` | `3306` |
| `MARIADB_ROOT_PASSWORD` | `PLUME_MARIADB_ROOT_PASSWORD` | `root` |
| `POSTGRES_PORT` | `PLUME_POSTGRES_PORT` | `5432` |
| `POSTGRES_USER` | `PLUME_POSTGRES_USER` | `postgres` |
| `POSTGRES_PASSWORD` | `PLUME_POSTGRES_PASSWORD` | `postgres` |
| `MYSQL_ROOT_PASSWORD` | `PLUME_MYSQL_ROOT_PASSWORD` | `root` |
| `MYSQL_PORT` | `PLUME_MYSQL_PORT` | `3307` |

Degisiklik sonrasi: `./plume.sh services restart <svc> --mode=native` (config sync otomatik).

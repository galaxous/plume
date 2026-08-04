# Native services manifest (`services.yml`)

Laradock’taki `docker-compose.yml` benzeri merkezi manifest: native modda hangi stack bileşenlerinin hedeflendiğini yapılandırır. **`.env` ortam katmanı olarak kalır**; aynı anahtar hem YAML’de hem `.env`’de tanımlıysa **`.env` kazanır**.

## Dosya konumu

| Dosya | Amaç |
|-------|------|
| `~/.config/plume/services.yml` | Kalıcı kullanıcı manifest (varsayılan) |
| `templates/services.yml.example` | Repodaki şablon (tüm registry servisleri) |
| `PLUME_SERVICES_MANIFEST_FILE` | Manifest yolu override |

`plumectl init host` manifest yoksa şablonu `~/.config/plume/services.yml` konumuna kopyalar (mevcut dosyanın üzerine yazmaz).

## Birleştirme sırası

1. `lib/config/defaults.sh` (gömülü varsayılanlar)
2. `services.yml` (yapılandırılmış servis tanımları)
3. `~/.config/plume/.env` (son söz; `plume_load_env`)

`host.env` makine tespiti içindir; servis toggle’ları için **değildir** (bkz. D-098).

## Şema (sürüm `version: 1`)

Özel bloklar (`web`, `php`, `database`, `provision`) + registry servisleri (blok veya inline `{ enabled: true, version: "16" }`).

Tam örnek: `templates/services.yml.example`.

### YAML → ortam eşlemesi (özet)

| YAML bölümü | Alan | Ortam değişkeni |
|-------------|------|-----------------|
| `web` | `engine` | `PLUME_WEB_SERVER_DRIVER` |
| `web` | `manage_main_config` | `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG` |
| `web` | `http_port` | `PLUME_NATIVE_NGINX_HTTP_PORT`, `PLUME_WEB_PORT` |
| `web` | `auto_provision` | `PLUME_SITE_AUTO_PROVISION_WEB`; `true` ise `PLUME_NATIVE_HOST_PROVISION=true` |
| `web` | `enabled` | `PLUME_WEB_SERVER_ENABLED` |
| `php` | `enabled` | `PLUME_PHP_ENABLED` |
| `php` | `default_version` | `PLUME_PHP_DEFAULT_VERSION`, `PLUME_PHP_VERSION` |
| `php` | `versions[]` | `PLUME_PHP_INSTALLED_VERSIONS` (virgülle) |
| `php` | `extensions_profile` | `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE` |
| `database` | `engine` | `PLUME_MARIADB_ENABLED` / `PLUME_MYSQL_ENABLED` |
| `database` | `version` | `PLUME_MARIADB_VERSION` veya `PLUME_MYSQL_VERSION` |
| `database` | `auto_start` | Provision sırasında DB start (manifest okuma; env değil) |
| `provision` | `interactive: false` | `PLUME_NONINTERACTIVE=true` |
| `provision` | `on_first_run: true` | İlk native bootstrap’ta (veya `init host`) bir kez `services provision --from-manifest`; tamamlanınca `state/on_first_run_provision.done` |

### Registry servisleri (tek tablo — D-104)

Her satır: `services.<name>.enabled` → `PLUME_*_ENABLED`, isteğe bağlı `version` → `PLUME_*_VERSION`. Kaynak: `plume_services_manifest_env_mapping_rows` + `lib/services/registry.sh` (`plume_service_env_key`).

| YAML `services.<name>` | Enabled env | Version env |
|------------------------|-------------|-------------|
| `composer` | `PLUME_COMPOSER_ENABLED` | `PLUME_COMPOSER_VERSION` |
| `phpmyadmin` | `PLUME_PHPMYADMIN_ENABLED` | `PLUME_PHPMYADMIN_VERSION` |
| `mariadb` | `PLUME_MARIADB_ENABLED` | `PLUME_MARIADB_VERSION` |
| `mysql` | `PLUME_MYSQL_ENABLED` | `PLUME_MYSQL_VERSION` |
| `postgres` | `PLUME_POSTGRES_ENABLED` | `PLUME_POSTGRES_VERSION` |
| `redis` | `PLUME_REDIS_ENABLED` | `PLUME_REDIS_VERSION` |
| `memcached` | `PLUME_MEMCACHED_ENABLED` | `PLUME_MEMCACHED_VERSION` |
| `rabbitmq` | `PLUME_RABBITMQ_ENABLED` | `PLUME_RABBITMQ_VERSION` |
| `mongodb` | `PLUME_MONGODB_ENABLED` | `PLUME_MONGODB_VERSION` |
| `mongo_webui` | `PLUME_MONGO_WEBUI_ENABLED` | `PLUME_MONGO_WEBUI_VERSION` |
| `redis_webui` | `PLUME_REDIS_WEBUI_ENABLED` | `PLUME_REDIS_WEBUI_VERSION` |
| `mailpit` | `PLUME_MAILPIT_ENABLED` | `PLUME_MAILPIT_VERSION` |
| `meilisearch` | `PLUME_MEILISEARCH_ENABLED` | `PLUME_MEILISEARCH_VERSION` |
| `minio` | `PLUME_MINIO_ENABLED` | `PLUME_MINIO_VERSION` |
| `supervisor` | `PLUME_SUPERVISOR_ENABLED` | `PLUME_SUPERVISOR_VERSION` |
| `horizon` | `PLUME_HORIZON_ENABLED` | `PLUME_HORIZON_VERSION` |
| `php_worker` | `PLUME_PHP_WORKER_ENABLED` | `PLUME_PHP_WORKER_VERSION` |

`database.engine` ile `mariadb`/`mysql` bölümleri birlikte kullanılabilir; son yazılan manifest alanı export sırasına göre env’i günceller (tercihen tek kaynak kullanın).

### Native host provision vs yalnızca enable

| Servis | Manifest `enabled` | `provision --from-manifest` (native) |
|--------|-------------------|--------------------------------------|
| web (nginx/apache2) | Evet | Kurulum + start |
| mariadb, mysql, redis | Evet | Kurulum + start (`database.auto_start` DB için) |
| postgres, mongodb, rabbitmq, phpmyadmin, mongo_webui, redis_webui | Evet (Phase 17) | Kurulum + start; OS matrisi bkz. [native-stack-os-matrix.md](./native-stack-os-matrix.md) |
| mailpit | Evet (env) | macOS Homebrew: kurulum + start; Linux: uyarı (docker-lite / manuel) |
| php (`versions[]`) | Evet | Best-effort brew/apt PHP kurulumu + matrix kaydı |
| postgres, memcached, … | Evet (env) | **memcached:** yok — docker-lite / manuel |
| phpmyadmin, composer, horizon, … | Evet (env) | **composer/horizon:** container veya manuel |

Laradock-bridge’e özgü compose adları (`workspace`, `php-fpm`) şablonda yorum olarak dokümante edilir; native loader bu satırları okumaz.

### Queue: `horizon`, `php_worker`, `supervisor` (D-113)

| Servis | `services.yml` | Native host provision | Calistirma |
|--------|----------------|----------------------|------------|
| `horizon` | `enabled` → `PLUME_HORIZON_ENABLED` | **Yok** — paket kurulumu yok | `services up horizon` — **supervisor** bagimliligi (native); runtime state / compose reconcile |
| `php_worker` | `enabled` → `PLUME_PHP_WORKER_ENABLED` | **Yok** | Genelde docker-lite / laradock **php-worker** container veya manuel `queue:work` |
| `supervisor` | `enabled` → `PLUME_SUPERVISOR_ENABLED` | **Yok** | Horizon on kosulu; native’de OS supervisor kurulumu Plume disi |

**Docker-lite:** Compose alias `laravel-horizon` ↔ Plume servis adi `horizon` (ve `supervisor` ayni container’a map edilebilir). Bkz. [services.md](../commands/services.md).

**Laradock-bridge:** `laravel-horizon`, `php-worker` compose servisleri; manifest yalnizca env toggle yukler, compose’u degistirmez.

**Operasyonel CLI:** `plume queue status`, `plume queue list`; Horizon acikken `services status horizon`. Manifest’te `horizon: { enabled: true }` yalnizca env hazirlar — otomatik Horizon kurulumu beklenmez.

## Komutlar

Etkin yapılandırmayı görmek (`effective_*` satırları, adapter-parse):

```bash
./plume.sh init onboarding          # checklist + effective_* satırları
./plume.sh services manifest show
```

Greenfield host (Homebrew / apt / dnf — mock smoke’larda brew shim):

```bash
./plume.sh env init
./plume.sh init host                  # host.env + services.yml bootstrap
./plume.sh init host --apply          # manifest’e göre native provision
# İlk CLI oturumu (manifest’te provision.on_first_run: true): otomatik provision (bir kez)
# veya
./plume.sh services provision --from-manifest
./plume.sh services provision --from-manifest --dry-run
```

Ek PHP sürümü manifest’te yoksa:

```bash
./plume.sh php install 8.4
./plume.sh init onboarding --fix      # brew services nginx/php
```

## macOS: otomatik olmayan adımlar

- **Full Disk Access**: `nginx` ve `php-fpm` binary’leri (Plume veya plume.sh değil). Bkz. [macos-permissions.md](./macos-permissions.md).
- **Desktop / Documents / Downloads** altında proje kökü: TCC; tercih `~/Sites` veya `~/Code`.
- **Port 80**: Homebrew nginx varsayılan 8080; `manage_main_config: true` + `services web sync-config --reload` veya 8080’de kalın.

## Geriye uyumluluk

Manifest dosyası yoksa loader no-op’tur; yalnızca `.env` + defaults davranışı sürer. Eksik YAML anahtarları mevcut env/defaults değerini değiştirmez.

## İlgili kararlar

- D-108 — `provision.on_first_run` otomatik manifest provision
- D-104 — tam registry manifest eşlemesi
- D-103 — `services.yml` native manifest MVP
- D-098 — `host.env`
- D-100 — interaktif kurulum promptları

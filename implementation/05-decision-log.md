# Decision Log (ADR-Lite)

Bu dosya, fazlar boyunca alinan teknik kararlarin kaydidir.

## 2026-10-02 - D-156 - Manual Release pre-tag VERSION + Formula version/url sync

- Durum: accepted
- Karar:
  - Tek workflow: [manual-release.yml](../.github/workflows/manual-release.yml) — smoke → tag → sync → force-tag → Release.
  - Sync script: [packaging/homebrew/sync-release-version.sh](../packaging/homebrew/sync-release-version.sh) ayni commit’te `VERSION` + her iki Homebrew formula `version`/`url` yazar.
  - `sha256` sync’te dokunulmaz (tarball hash frozen tag sonrasi; `:no_check` veya retag’siz `main` bump).
  - galaxous/github-workflows `reusable-manual-release` VERSION sync modeli ile uyumlu; Formula genisletmesi Plume-side (reusable henuz multi-file/formula hook yok).
- Gerekce:
  - Elle formula senkronu hata egilimli; tag icerigi `plumectl version` + brew `url`/`version` ile hizali olmali.
- Etki:
  - Maintainer checklist sadelesti; phase28 smoke sync script + formula↔VERSION assert.

## 2026-09-29 - D-155 - Pinned VERSION + Homebrew/Packagist release (Herd P3)

- Durum: accepted
- Karar:
  - Repo `VERSION` tek kaynak; `plumectl version` / `--json version` okur.
  - Yayin: [release.md](../docs/operations/release.md) + [install.md](../docs/operations/install.md).
  - Manual Release workflow `./tests/run_smoke_suite.sh --release` gate.
  - Homebrew formula: `packaging/homebrew/plumectl.rb` + `Formula/plumectl.rb` (`plumectl` / alias `plume`).
  - Packagist: `galaxous/laravel-plume` (`composer.json`, `bin/plumectl`); auto-update = `brew upgrade` / `composer global update`.
  - Linux: distro-agnostic `packaging/linux/install.sh` (`PLUME_REF`, `PREFIX`); `.deb`/`.rpm` yok.
  - Asamali kurulum: [install.md](../docs/operations/install.md) A–H (maintainer → macOS → Debian/Ubuntu → RHEL/Fedora → diger Linux).
  - `plumectl self-update` bilerek yok.
  - Surum bump CI: D-156 (VERSION + formula version/url).
- Gerekce:
  - Kullanici onceligi P4 sonra P3; hard-coded surum + yalnizca clone/`make install` yetersiz; Linux distrolari atlanmamali.
- Etki:
  - Faz 28 done, `VERSION`, composer.json, Formula, linux install.sh, phase28 smoke, manual-release.yml.

## 2026-09-27 - D-154 - Composer + Node workspace CLI (Herd parity P4)

- Durum: accepted
- Karar:
  - Yeni komutlar: `plumectl composer|npm|node` (`lib/commands/workspace.sh`).
  - Proje yolu: `--path` / `--site` / cwd site eslesmesi / cwd / mode path.
  - Native Composer: site veya default PHP `PATH` basina eklenir (`COMPOSER_PHP` mumkunse).
  - docker-lite / laradock-bridge: `workspace` container `exec -T`.
  - Binary override: `PLUME_COMPOSER_BIN`, `PLUME_NPM_BIN`, `PLUME_NODE_BIN`.
  - Oncelik: P4 once, sonra P3 release; P1 Docker-lite ve P2 meilisearch/minio ertelendi (kullanici).
- Gerekce:
  - Herd parity acik maddesi; `project init` yalnizca bootstrap, gunluk `composer`/`npm` yuzeyi yoktu.
- Etki:
  - Faz 27, [workspace.md](../docs/commands/workspace.md), `phase27_workspace_composer_npm_smoke.sh`.

## 2026-09-17 - D-153 - Homebrew supervisor drop-in: etc/supervisor.d/*.ini

- Durum: accepted
- Karar:
  - Homebrew `supervisord.conf` include: `/opt/homebrew/etc/supervisor.d/*.ini` (formula `opt/supervisor/etc/.../*.conf` degil).
  - Plume program path/ext: main conf `[include] files=` satirindan turetilir; brew varsayilan ext=`ini`.
  - Stale `host.env` `supervisor_programs_dir=.../opt/supervisor/etc/supervisor.d` yok sayilir; yazimda eski `.conf` temizlenir.
- Gerekce:
  - Horizon conf yaziliyordu ama supervisord programi gormuyordu (`ERROR no such process`); Redis healthy olsa bile Horizon stopped kaliyordu.
- Etki:
  - `native_supervisor.sh`, `phase26_supervisor_brew_ini_smoke.sh`, docs services-supervisor/horizon.

## 2026-09-17 - D-152 - Horizon/supervisor diagnose via Plume only

- Durum: accepted
- Karar:
  - Kullaniciya `supervisorctl` / `brew services` yazdirilmaz; teşhis ve remediation yalnizca `plumectl` komutlari.
  - `services up horizon` saglik basarisizsa program status + worker log kuyrugu + `doctor`/`logs`/`restart` ipuclari basar.
  - `services logs horizon [--site=]` native per-site `horizon-<site-id>.log` dosyalarini okur.
  - Drop-in henuz yuklenmediyse Plume system supervisor'i sessizce restart eder (brew mesaji gizlenir).
  - `doctor supervisor` horizon WARN/FAIL satirlari plumectl remediation icerir.
- Gerekce:
  - Horizon stopped/health fail senaryosunda kullanici brew/supervisorctl'e itiliyordu; urun sozu plumectl-only.
- Etki:
  - `native_horizon.sh`, `native_supervisor.sh`, `registry.sh` logs, doctor, [services-horizon.md](../docs/commands/services-horizon.md).

## 2026-09-15 - D-151 - Native nginx HTTP port 80 guarantee (macOS + Linux)

- Durum: accepted
- Karar:
  - Varsayilan `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true`, hedef `PLUME_NATIVE_NGINX_HTTP_PORT=80`.
  - Site snippet render: manage acikken *desired* port kullanilir (main conf hâlâ 8080 olsa bile `listen 80` yazilir).
  - `plumectl services web ensure`: main conf sync + privileged bind (sudo/brew|systemctl) + tum native nginx sitelerini republish.
  - `site publish` / `services up|restart web`: otomatik ensure (`PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH` / `_ON_WEB_UP`, default true).
  - macOS Homebrew ve Linux `/etc/nginx/nginx.conf` path'leri; port < 1024 elevated restart.
- Gerekce:
  - Kullanici `http://site.test` (portsuz) bekler; brew 8080 + opt-in sync UX'i Plume amacina aykiridir.
- Etki:
  - `native_web_nginx_config.sh`, `services web ensure`, site publish hook, docs/commands/services-web.md.

## 2026-08-30 - D-150 - Per-site native Horizon supervisor programs

- Durum: accepted
- Karar:
  - Her Plume site kaydi icin ayri supervisor programi: `plume-horizon-<site-id>`; proje yolu site `path`, PHP site `php_version`.
  - Site kaydinda `horizon: true|false`; CLI: `site add|update --horizon` / `--no-horizon`.
  - `services up|down horizon [--site=<site-id>]`: tum horizon-enabled siteler veya tek site.
  - Legacy tek program (`plume-horizon` + `PLUME_HORIZON_PATH`) yalnizca horizon-enabled site yokken fallback.
  - `doctor supervisor`: site basina `horizon-program:<site-id>` satirlari.
- Gerekce:
  - Cok projeli gelistirme ortaminda global `PLUME_HORIZON_PATH` yetersiz; Herd/Laradock'ta proje basina worker beklentisi.
- Etki:
  - `lib/services/native_horizon.sh`, `site` komutu, `phase24_per_site_horizon_smoke.sh`, [services-horizon.md](../docs/commands/services-horizon.md).

## 2026-08-30 - D-149 - System-primary supervisor + doctor + upgrade --force

- Durum: accepted
- Karar:
  - Native supervisor runtime: sistem birincil (`brew services supervisor` / `systemctl`), D-147 Plume-owned supervisord legacy; `services supervisor upgrade --force --yes` migrasyon.
  - `doctor supervisor`: host.env cache, binary/unit/schema/registry/horizon kontrolleri; REMEDIATION satiri.
  - Ilk `--force` kapili upgrade: `--force` + `--yes` zorunlu; `--dry-run` plan.
  - `services supervisor program add`: template + interaktif placeholder sorulari; conf OS drop-in + registry.
  - `host.env`: `supervisor_*` alanlari persist (`plume_host_profile_set_value`).
- Gerekce:
  - Kullanici sistem supervisor + tam yetkiyle conf ekleme istedi; D-147 state-dir daemon operasyonel degil.
- Etki:
  - `lib/services/native_supervisor.sh`, `doctor supervisor`, `services supervisor`, `phase-23.md`, D-147 partial supersede.

## 2026-08-18 - D-148 - Native Redis keeps configured port if already listening

- Durum: accepted
- Karar:
  - `services up redis` preferred port (`6379`) baska bir process ise +1 arar; listener zaten `redis-server` ise portu degistirmez.
- Gerekce:
  - `sync-config --reload` veya mevcut brew Redis 6379 tutarken `up` 6380'e kayiyordu; Laravel `REDIS_PORT=6379` kiriliyordu.
- Etki:
  - `plume_service_allocate_explicit_port`, [services-redis.md](../docs/commands/services-redis.md).

## 2026-08-18 - D-147 - Native supervisor + Horizon host worker

- Durum: accepted
- Karar:
  - `supervisor` / `horizon` native driver: brew/apt `supervisor` binary; Plume-owned `supervisord` (state dir + detach, D-140). Homebrew `brew services supervisor` kullanilmaz.
  - Horizon program: `php artisan horizon` (`PLUME_HORIZON_PATH` veya ilk site artisan).
  - `health=healthy` yalnizca supervisorctl RUNNING/STARTING; `php_worker` registry-only kalir.
  - Mock/smoke: `PLUME_NATIVE_HOST_INSTALL_DRIVER=mock` — brew install yok.
- Gerekce:
  - D-146 honesty sonrasi kullanici gercek worker istiyor; Laravel `QUEUE_CONNECTION=redis` native stack ile tamamlansin.
- Etki:
  - `lib/services/native_horizon.sh`, drivers, `phase-22.md`, `docs/commands/services-horizon.md`.

## 2026-08-12 - D-146 - Native queue/search honesty (registry-only)

- Durum: accepted
- Karar:
  - `horizon` / `supervisor` / `php_worker`: native `up` exit 0 + WARN; `health=registry` (host daemon yok). Fail-fast yok — mevcut phase6/11 smoke’lar supervisor ile `up` basarisini bekler.
  - `meilisearch` / `minio`: ayni registry-only; WARN `toggle-only`; native driver backlog (Herd parity).
  - Gercek brew supervisor / meilisearch/minio host driver sonraki faz.
- Gerekce:
  - `up @core` (eski) horizon’u running gosteriyordu; yari-yalan UX. Docker-lite/laradock gercek worker icin dogru yol.
- Etki:
  - `native_host_provision.sh`, `registry.sh` start warn, `phase-21.md`, `phase21_queue_honesty_smoke.sh`.

## 2026-08-12 - D-145 - Native memcached + cache/broker contract

- Durum: accepted
- Karar:
  - memcached: brew/apt/dnf driver, port 11211, credentials `127.0.0.1`, `@cache` uyesi.
  - mongodb / rabbitmq / mongo_webui / redis_webui ayni native-service-contract (D-144) ile dogrulanir.
- Gerekce:
  - Laravel cache/session/queue broker opsiyonelleri Laradock container UX’i istiyor; memcached Phase 17’de yalnizca toggle idi.
- Etki:
  - `native_host_service_drivers.sh`, `phase-20.md`, `docs/commands/services-memcached.md`.

## 2026-08-12 - D-144 - Native service contract (Laradock-container UX)

- Durum: accepted
- Karar:
  - Her native servis: enable → `services up` → live health → credentials/url; TCP host `127.0.0.1`.
  - `@core`: php, composer, web, DB engines, redis, phpmyadmin, pgadmin, mailpit — **queue yok**.
  - Status: live probe; stale PID / olu brew → `stopped` (yalan `starting` yok). HTTP canli PID → `starting`.
  - `services use mariadb|mysql|postgres`: XOR + phpmyadmin/pgadmin esleme + `database.engine` (mysql-family).
  - Docker-lite unfreeze bu native P0’in **arkasina** alinir.
- Gerekce:
  - D-138..D-143 dersleri (detach, leak, loopback, stdout) tum kritik servislere yayilmali.
- Etki:
  - [native-service-contract.md](../docs/operations/native-service-contract.md), `phase-19.md`, `cmd_services_use`.

## 2026-08-09 - D-143 - mysqladmin ping without --batch (MariaDB 12 client)

- Durum: accepted
- Karar:
  - Native mariadb/mysql health: `mysqladmin ping ... --silent` with stdout+stderr → `/dev/null` (no `--batch`).
  - MariaDB 12 client: `--batch` unknown; `--silent` still prints `mysqld is alive` → must redirect stdout or status HEALTH column corrupts.
- Gerekce:
  - Probe fail / `HEALTH=mysqld is alive` / status parse break.
- Etki:
  - `lib/services/native_host_service_drivers.sh`.

## 2026-08-09 - D-142 - Native phpMyAdmin connect host is 127.0.0.1

- Durum: accepted
- Karar:
  - `config.inc.php` server `host` = `127.0.0.1`; `verbose` = `mariadb|mysql` (dropdown etiketi).
  - `/etc/hosts` alias opsiyonel; sudo olmadan yazilamazsa login kirilmaz.
  - Credentials dosyasi phpmyadmin icin yeniden yazilir (sadece enabled engines).
- Gerekce:
  - Hosts sync skip → `getaddrinfo for mariadb failed`; kullanici credentials girse de baglanamiyordu.
- Etki:
  - `native_phpmyadmin_config.sh`, drivers credentials, smoke, docs.

## 2026-08-09 - D-141 - phpMyAdmin smoke must not leak host :8081

- Durum: accepted
- Karar:
  - Mock `php -S` shim: `exec python3 -m http.server --bind 127.0.0.1` (PID = listener; no orphan nohup).
  - Smoke cleanup: kill phpmyadmin pid + stray `http.server.*8081` on host.
- Gerekce:
  - Eski smoke `nohup python3 -m http.server 8081` host'ta kalip temp docroot silinince Python 404; gercek phpMyAdmin port busy → 8082'ye kayiyordu; kullanici `localhost:8081` acinca 404.
- Etki:
  - `tests/phase17_native_phpmyadmin_smoke.sh`, `tests/phase11_native_core_services_parity_smoke.sh`.

## 2026-08-09 - D-140 - Detach native HTTP daemons + stale PID status

- Durum: accepted
- Karar:
  - `plume_native_detach_daemon`: double-fork + `setsid` (Python); parent shell/process-group kill daemon'i olduremez.
  - pgadmin / phpmyadmin / npm webui start bu helper'i kullanir.
  - `plume_service_health`: managed HTTP serviste probe fail + PID oluyse `running=false` + `stopped` (yanlis "starting" yok).
  - HTTP probe: 2xx/3xx kabul (`curl -sf` yerine http_code).
- Gerekce:
  - Agent/terminal shell teardown `nohup` pgadmin PID'ini olduruyordu; status `running=true` / `starting` + browser ERR_CONNECTION_REFUSED.
- Etki:
  - `native_host_service_drivers.sh`, `native_pgadmin.sh`, `native_phpmyadmin_config.sh`, `registry.sh`.

## 2026-08-07 - D-139 - pgAdmin namespace package path + writable DATA_DIR

- Durum: accepted
- Karar:
  - `pgadmin4.__file__` namespace pakette `None`; paket yolu `pgadmin4.__path__[0]` (+ site-packages fallback).
  - `config_local.py`: `DATA_DIR` / `SQLITE_PATH` / `LOG_FILE` → `state/native/pgadmin/data` (`/var/lib/pgadmin` yok).
  - Start sonrasi HTTP ready wait (ilk boot yavas); mevcut venv'de tekrar pip skip.
- Gerekce:
  - Install pip OK iken `package not found`; start `/var/lib/pgadmin` Permission denied → running=false / health=stopped.
- Etki:
  - `lib/services/native_pgadmin.sh`.

## 2026-08-07 - D-138 - Native pgAdmin (Laradock pgadmin parity)

- Durum: accepted
- Karar:
  - Yeni registry servisi `pgadmin`: PostgreSQL web UI (phpMyAdmin MySQL-family karsiligi).
  - Kurulum: `state/native/pgadmin/venv` + `pip install pgadmin4` (sistem cask/desktop degil; HTTP PID yonetimi).
  - Env Laradock isimleri: `PGADMIN_ENABLED`, `PGADMIN_PORT=5050`, `PGADMIN_DEFAULT_EMAIL`, `PGADMIN_DEFAULT_PASSWORD`.
  - Dependency: `postgres` enabled; `@db` grubuna eklendi.
  - Mock driver: hermetik stub binary (gercek pip yok).
- Gerekce:
  - Kullanici Postgres'i phpMyAdmin gibi UI ile yonetmek istiyor; Laradock'ta `pgadmin` var, Plume native'de yoktu.
- Etki:
  - `lib/services/native_pgadmin.sh`, drivers/registry/services CLI, docs, `phase18_native_pgadmin_smoke.sh`, phase-18.

## 2026-08-07 - D-137 - Mock MariaDB include only when MAIN_CONF overridden

- Durum: accepted
- Karar:
  - Mock `mariadb`/`mysql` sync: `!include` yalnizca `PLUME_NATIVE_MARIADB_MAIN_CONF` set ise (hermetic temp file).
  - Gercek Homebrew `my.cnf` mock lifecycle'da degistirilmez.
- Gerekce:
  - D-134 mock include skip: `phase17-native-db-broker-config` `[FAIL] mariadb include`.
- Etki:
  - `lib/services/native_db_broker_config.sh`.

## 2026-08-07 - D-136 - Hosts sync never uses interactive sudo

- Durum: accepted
- Karar:
  - `plume_fs_copy_no_tty`: writable `cp` veya `sudo -n cp` (tty Password: yok).
  - `plume_native_db_hosts_sync` + site hosts add/remove bu helper'i kullanir.
  - Smoke: `PLUME_NATIVE_DB_HOSTS_SYNC=false` (phase11).
- Gerekce:
  - Release smoke `phase11-native-core-services-parity`: mariadb up sonrasi `sudo cp /etc/hosts` interaktif Password prompt (stderr redirect yetmez; /dev/tty).
- Etki:
  - `lib/common/os.sh`, `lib/services/native_db_hosts.sh`, `lib/common/sites.sh`, `tests/phase11_native_core_services_parity_smoke.sh`.

## 2026-08-07 - D-135 - Mailpit native health probe (mock + HTTP)

- Durum: accepted
- Karar:
  - `plume_native_driver_default_port` mailpit: `PLUME_MAILPIT_PORT` (8025).
  - Health probe: allocated port (`plume_service_effective_port`) + curl.
  - `phase12-native-host-provision-mailpit` smoke: mock `curl` (8025) + mock brew.
- Gerekce:
  - Release smoke: `services up mailpit` exit 2 — health probe `return 1` (mailpit npm/phpmyadmin path disinda).
- Etki:
  - `lib/services/native_host_service_drivers.sh`, `tests/phase12_native_host_provision_mailpit_smoke.sh`.

## 2026-08-07 - D-134 - MariaDB root bootstrap never prompts on tty

- Durum: accepted
- Karar:
  - `plume_native_mariadb_apply_root_password`: sifresiz TCP `mysql` denemesi kaldirildi (tty'de `Password:` ile CI/smoke takilmasi).
  - Socket auth (Homebrew varsayilan) sonra `--batch` ALTER USER; basarisizsa sessizce atla.
  - `mysqladmin` health probe: `--batch` + `</dev/null`; sifre yoksa socket ping, sifresiz TCP yok.
  - Mock driver config sync host `my.cnf` dosyasina yazmaz.
  - Smoke suite: `PLUME_NONINTERACTIVE=1` varsayilan; phase11 DB mock'a `mysql` shim eklendi.
- Gerekce:
  - Release smoke `phase11-native-core-services-parity`: gercek brew mariadb sonrasi interaktif `Password:` prompt.
- Etki:
  - `lib/services/native_db_broker_config.sh`, `lib/services/native_host_service_drivers.sh`, `tests/run_smoke_suite.sh`, `tests/phase11_native_core_services_parity_smoke.sh`.

## 2026-08-07 - D-133 - Phase11 DB parity smokes use hermetic mock driver

- Durum: accepted
- Karar:
  - `phase11-native-core-services-parity` mariadb/mysql/phpmyadmin adimlari mock brew + mysqladmin/php ile calisir (`PATH=${MOCK_BIN}:/usr/bin:/bin`).
  - php-fpm ve web driver adimlari gercek host entegrasyonu olarak kalir; SQL motorlari brew tek-formula kisiti nedeniyle mock.
  - Invalid-engine smoke: `PMA_ARBITRARY=0` (varsayilan `1` iken engine dogrulamasi atlanir).
- Gerekce:
  - Release smoke: `mysql start native` fail — host'ta yalnizca `mariadb` formula, `brew services start mysql` + health probe exit 2.
- Etki:
  - `tests/phase11_native_core_services_parity_smoke.sh`.

## 2026-08-06 - D-132 - Native registry-only services skip health gate

- Durum: accepted
- Karar:
  - `horizon`, `supervisor`, `php_worker` native modda brew/npm host driver yok; `services up` yalnizca registry/runtime kaydi yapar.
  - D-128 health gate yalnizca `plume_native_host_runtime_managed` servislerde calisir; `horizon`/`supervisor`/`php_worker` registry-only listesinde probe atlanir.
  - `plume_service_health`: registry-only -> `registry`; `php`/`composer` running -> `healthy` (host driver disi, ayri yasam dongusu).
- Gerekce:
  - `phase6-service-update-path` smoke: `horizon starts when supervisor enabled` exit 2 (probe fail) D-128 sonrasi.
- Etki:
  - `lib/services/native_host_provision.sh`, `lib/services/registry.sh`.

## 2026-08-06 - D-131 - Env-file load respects Laradock alias pairs

- Durum: accepted
- Karar:
  - `plume_load_env` preservation: env dosyasi alias ciftinin bir ucunu tanimliyorsa (`REDIS_ENABLED` veya `PLUME_REDIS_ENABLED`), diger uc preserve edilmez.
  - Env source sonrasi: dosyada yalnizca `PLUME_*` tanimliysa kisa isim ona senkronize edilir (defaults/manifest'ten kalan stale `REDIS_ENABLED=false` inward sync'te kazanmasin).
  - `plume_env_laradock_plume_to_short` eklendi.
- Gerekce:
  - D-130 sonrasi `--env-file` ile yalnizca `PLUME_REDIS_ENABLED=true` yazildiginda, onceden export edilen `REDIS_ENABLED=false` preserve ediliyordu; inward alias kisa ismi kazandiriyordu.
- Etki:
  - `lib/common/env.sh`, `lib/common/stack_service_env.sh`, `docs/operations/env-contract.md`.

## 2026-08-06 - D-130 - Laradock-style env names (config canonical)

- Durum: accepted
- Karar:
  - `.env.example`, `services.yml`, kullanici `.env`: stack servis toggle/port/credential icin `PLUME_` prefixi kaldirildi (ornek `REDIS_ENABLED`, `MARIADB_PORT`).
  - `plume_env_apply_laradock_aliases_*` (`stack_service_env.sh`): outward (defaults→short) → manifest → refresh (PLUME→short) → `.env` → inward (short→PLUME).
  - `services.yml` `${VAR}`: Laradock-style kisa isimler (ornek `${REDIS_ENABLED}`); eski `${PLUME_*}` geriye uyumlu.
  - Plume-ozel anahtarlar (`PLUME_STATE_DIR`, `PLUME_MODE`, native driver ayarlari) `PLUME_` prefixinde kalir.
- Gerekce:
  - Laradock parity; config dosyalarinda tanidik isimlendirme; runtime kod degisikligi minimize (alias katmani).
- Etki:
  - `stack_service_env.sh`, `env.sh`, `bootstrap.sh`, `.env.example`, `templates/services.yml.example`, docs, smoke.

## 2026-08-06 - D-129 - Native allocated port export + health probe retry

- Durum: accepted
- Karar:
  - `plume_service_start_native`: allocate sonrasi `PLUME_*_PORT` export (docker-lite parity); port degisti ve config-manage aciksa reload; health probe 3 deneme (reload + 1s bekleme).
  - Explicit `services up <svc>`: `provision_service_wants` false olsa da desteklenen servislerde `plume_native_host_start_service` calisir.
  - Redis config/health: `plume_service_effective_port` (allocated port oncelikli).
  - `services.yml` sablon: block YAML + quoted `${PLUME_*}` (IDE YAML parser uyumu).
- Gerekce:
  - D-128 health gate: 6379 mesgul → 6380 allocate ama probe/config 6379; brew restart olmadan fail.
- Etki:
  - `registry.sh`, `native_redis_config.sh`, template, docs, phase11 smoke hermetic skip.

## 2026-08-05 - D-128 - Native DB status probe, manifest `${VAR}`, brew dual-engine guard

- Durum: accepted
- Karar:
  - `plume_service_start_native`: `running=true` yalnizca basarili start + `plume_native_host_health_probe` sonrasi (mysqladmin stdout /dev/null).
  - `plume_service_status` (native): saglik `plume_service_health` ile; stale `running` bayragi tek basina `healthy` gostermez.
  - Manifest loader: `${PLUME_*}` placeholder interpolation (defaults sonrasi, `.env` oncesi); `.env` kazanir.
  - Native brew: `PLUME_MARIADB_ENABLED` + `PLUME_MYSQL_ENABLED` ikisi birden → manifest uyari, start/provision hata.
  - `database.engine` tek native brew engine; phpMyAdmin yalnizca operasyonel engine listeler (mevcut).
- Gerekce:
  - `services status mysql` brew kurulu degilken `running healthy` false positive; Laradock-style manifest discoverability; mariadb/mysql brew cakismasi.
- Etki:
  - `registry.sh`, `services_manifest.sh`, `native_db_hosts.sh`, `templates/services.yml.example`, docs, smoke.

## 2026-08-05 - D-127 - Native phpMyAdmin multi-server (mariadb|mysql + hosts)

- Durum: accepted
- Karar:
  - Aktif engine basina phpMyAdmin server kaydi: `verbose`/`host`=`mariadb|mysql`, port=`PLUME_*_PORT`.
  - `PLUME_NATIVE_DB_HOSTS_SYNC`: `/etc/hosts` → `127.0.0.1 mariadb mysql` (Laradock hostname parity).
  - Varsayilan `PLUME_MYSQL_PORT=3307` (mariadb 3306 ile cakismasin).
  - Login: dropdown veya Server alanina `mariadb`/`mysql` + user/password.
- Gerekce:
  - Laradock'ta iki ayri container ve docker network hostname; native'de ayni UX icin farkli port + hosts alias.
- Etki:
  - `native_phpmyadmin_config.sh`, `native_db_hosts.sh`, drivers, defaults, smoke, docs.

## 2026-08-05 - D-126 - phpMyAdmin Laradock arbitrary server parity

- Durum: accepted
- Karar:
  - `PMA_ARBITRARY=1` (varsayilan) iken native `config.inc.php` sabit `host`/`port` yazmaz; Server login formunda girilir (Laradock gibi).
  - `PMA_DB_ENGINE` native + arbitrary modda opsiyonel; yalnizca docker-lite `depends_on` ve `PMA_ARBITRARY=0` sabit hedef icin.
  - Native login Server: `127.0.0.1`; docker-lite: `mariadb` veya `mysql` container hostname.
- Gerekce:
  - Laradock login UX: Server + user + password; `PMA_DB_ENGINE` compose dependency, phpMyAdmin config degil.
- Etki:
  - `native_phpmyadmin_config.sh`, `registry.sh`, docs, smoke, `.env.example`.

## 2026-08-05 - D-125 - Native phpMyAdmin cookie auth (login formu)

- Durum: accepted
- Karar:
  - Native `config.inc.php` varsayilan `PMA_AUTH_TYPE=cookie`; kullanici MariaDB sifresini login formunda girer.
  - `PMA_AUTH_TYPE=config` opt-in: `PMA_USER`/`PMA_PASSWORD` config'e yazilir (Laradock/docker otomatik giris parity).
  - `services credentials phpmyadmin` DB ipuclarini vermeye devam eder; sifre config'e gomulmez (cookie modunda).
- Gerekce:
  - `auth_type=config` native 8081'de sifre sormadan oturum aciyordu; beklenen yerel dev UX degil.
- Etki:
  - `native_phpmyadmin_config.sh`, smoke, `.env.example`, `services-phpmyadmin.md`.

## 2026-08-05 - D-124 - Native phpMyAdmin (brew + PMA config.inc.php)

- Durum: accepted
- Karar:
  - macOS: `brew install phpmyadmin`; npm yolu kaldirildi.
  - `PMA_*` / `PLUME_PHPMYADMIN_*` → `state/native/phpmyadmin/htdocs/config.inc.php`.
  - `php -S 127.0.0.1:<port>` PID yonetimi; `services restart phpmyadmin` config sync + yeniden baslatma.
  - Smoke: `phase17_native_phpmyadmin_smoke.sh`; docs: `services-phpmyadmin.md`.
- Gerekce:
  - Native 8081 erisilemiyordu: bos docroot + npm yanlis kurulum yolu.
- Etki:
  - `native_phpmyadmin_config.sh`, drivers, services credentials, tests, docs.

## 2026-08-05 - D-123 - Native DB/Broker Config Management (MariaDB, Postgres, MongoDB, RabbitMQ)

- Durum: accepted
- Karar:
  - Redis modeli genisletildi: `PLUME_*` → plume include/block + `services restart <svc>` otomatik sync.
  - Servisler: mariadb, mysql, postgres, mongodb, rabbitmq; toggle: `PLUME_NATIVE_*_MANAGE_CONFIG=true` (varsayilan).
  - Ortak helper: `native_stack_config_common.sh`; driver: `native_db_broker_config.sh`.
  - Runtime sifre/kullanici: restart sonrasi best-effort SQL/shell (`ALTER USER`, `mongosh`, `rabbitmqctl`).
  - Smoke: `phase17_native_stack_db_broker_config_smoke.sh`.
- Gerekce:
  - Kullanici `.env` degistirir → `services restart <svc>` yeterli; brew config elle duzenleme yok.
- Etki:
  - drivers, defaults, stack_service_env, tests, docs.

## 2026-08-05 - D-122 - Native Redis Config Management

- Durum: accepted
- Karar:
  - `PLUME_NATIVE_REDIS_MANAGE_CONFIG=true` (varsayilan): `PLUME_REDIS_PORT`, `PLUME_REDIS_PASSWORD`, `PLUME_NATIVE_REDIS_BIND` → `state/native/redis/plume-redis.conf` + system `redis.conf` include.
  - `services redis sync-config [--reload|--dry-run]`; `install|up|restart redis` otomatik sync.
  - Health: `redis-cli` port + sifre ile ping.
- Gerekce:
  - Laradock parity: env'deki sifre/port native Redis'e uygulanmali; kullaniciya manuel `redis.conf` duzenletilmemeli.
- Etki:
  - `lib/services/native_redis_config.sh`, drivers, `services.sh`, docs, smoke.

## 2026-08-05 - D-121 - Stack Service Env Defaults (Laradock Parity)

- Durum: accepted
- Karar:
  - Redis, MongoDB, RabbitMQ, mongo_webui, redis_webui icin Laradock-hizali `PLUME_*` varsayilanlari (`defaults.sh`, `.env.example`): port, kullanici, sifre, management port, web UI auth.
  - `.env` degisikligi sonrasi runtime uygulama: `services restart <svc> --mode=native`; npm web UI servisleri env'i start sirasinda okur.
  - CLI: `env set PLUME_*=...`, `services env show|set <svc> <short=val>` (`password=`, `port=`, …); `--restart` ile aninda uygulama.
  - Laradock esleme tablosu: `docs/operations/env-contract.md`.
- Gerekce:
  - Native stack operasyonu Laradock `.env` aliskanligina yakin; sifre/port degisikligi belgelenmis restart yolu gerektirir.
- Etki:
  - `lib/common/stack_service_env.sh`, `lib/config/defaults.sh`, `native_host_service_drivers.sh`, `envcmd.sh`, `services.sh`, tests, docs.

## 2026-08-04 - D-120 - Phase 17 Gate Closure (Native Stack Host Parity)

- Durum: accepted
- Karar:
  - Faz 17 resmi kapanis: tracker `done`, tamamlanma 2026-08-04.
  - Gate: native drivers + `services url|credentials` + `@cache` + auto-provision D-119, phase17 smoke release zincirinde, `./tests/run_smoke_suite.sh --release` yesil.
- Gerekce:
  - AGENTS.md faz-gate.
- Etki:
  - `implementation/phases/phase-17.md`, `implementation/11-status-2026-08-04.md`, release runner, CI workflow.

## 2026-08-04 - D-119 - Phase 17 Native Stack Host Parity (Scope)

- Durum: accepted
- Karar:
  - Native modda Phase 17 servisleri: mariadb, mysql, postgres, phpmyadmin, redis, mongodb, rabbitmq, mongo_webui, **redis_webui** (yeni registry; Laradock `redis-webui` alias).
  - OS matrisi: macOS brew + Linux apt/dnf; dokuman [native-stack-os-matrix.md](../docs/operations/native-stack-os-matrix.md); AGENTS.md §9.
  - **redis_webui** urunu: **redis-commander** (npm global); RedisInsight doc alternatif.
  - Auto-provision: `PLUME_NATIVE_SERVICE_AUTO_PROVISION=true` default — native `services up` enabled servislerde host install+start (mailpit modeli genisletildi); `--no-provision` escape.
  - CLI: `services url`, `services credentials`; `@cache` grubu; `@db` safe-order (DB engine → phpmyadmin).
- Gerekce:
  - Laradock-parity native deneyimi; YAML/env disinda operasyonel komut yuzeyi.
- Etki:
  - `lib/services/native_host_service_drivers.sh`, `native_host_provision.sh`, `registry.sh`, `services.sh`, tests, docs.

## 2026-07-29 - D-118 - Phase 16 Gate Closure (plume.yml v2 MVP)

- Durum: accepted
- Karar:
  - Faz 16 resmi kapanis: tracker `done`, tamamlanma 2026-07-29.
  - Gate: MVP loader + `project config show` + `site add` php/mode hint, D-117, `tests/phase16_plume_yml_v2_smoke.sh` release zincirinde, `./tests/run_smoke_suite.sh --release` yesil.
  - Stretch (manifest sync, `services.enabled[]`) Faz 16b veya sonraki faz backlog'unda kalir.
- Gerekce:
  - AGENTS.md faz-gate: test + dokumantasyon + karar kaydi.
- Etki:
  - `implementation/phases/phase-16.md`, `implementation/phase-tracker.md`, `implementation/10-herd-parity-and-beyond.md`, `implementation/11-status-2026-07-29.md`, `implementation/future-roadmap.md`.

## 2026-07-28 - D-117 - Phase 16 plume.yml v2 MVP (Schema, Loader, Merge)

- Durum: accepted
- Karar:
  - Proje kokundeki `plume.yml` icin MVP alanlari: `project.mode`, `project.php_version`, `project.type` (opsiyonel); opsiyonel kok `version` ve phase-4 geriye uyumlu kok `mode`.
  - Mode cozumleme onceligi (manifest tarafi): CLI `--mode` > `project.mode` > kok `mode` > `PLUME_MODE` / hint > `mode current`.
  - PHP surumu: `site add` icinde `--php` / `--php-version` verilmediyse `project.php_version` hint olarak kullanilir; kurulu surum listesi (`PLUME_PHP_INSTALLED_VERSIONS` / env) validation'da son soz sahibidir.
  - Stack enable / servis profili: kullanici `~/.config/plume/services.yml` + `.env` (D-103/D-104); proje manifest servis toggle'lari Phase 16 stretch — bu fazda yuklenmez.
  - Site registry (`~/.config/plume/sites` veya `PLUME_SITE_REGISTRY_DIR`): kayit alanlari (domain, path, mode, php_version) manifest ile cakismada CLI ve registry kaydi site operasyonu icin authoritative; manifest yalnizca onboarding hint/cozumleme katmanidir (otomatik registry sync yok).
  - Loader: `lib/common/plume_yml.sh`; gorunurluk: `plumectl project config show --path=...`.
- Gerekce:
  - D-089 backlog'un dar MVP dilimini kod + hermetik smoke ile teslim etmek; phase-4 mode davranisini bozmadan `project.*` alanlarini netlestirmek.
- Etki:
  - `lib/common/plume_yml.sh`, `lib/commands/site.sh`, `lib/commands/project.sh`, `tests/phase16_plume_yml_v2_smoke.sh`, `tests/run_smoke_suite.sh --release`, `docs/operations/project-plume-yml.md`, `docs/commands/project-config.md`.

## 2026-07-28 - D-116 - Phase 15 CI / Release Readiness Parity

- Durum: accepted
- Karar:
  - `tests/run_smoke_suite.sh --release` icindeki `phase15_scheduler_queue_smoke.sh` adimi `.github/workflows/smoke-tests.yml` ile birebir hizalanir (README `--ci` iddiasi).
  - `docs/operations/release-readiness.md` release zinciri listesine Faz 15 adimi eklenir.
  - `implementation/phases/phase-15.md` gate yapisi faz 13/14 ile hizalanir; `phase-15-scheduler-queue.md` arsiv olarak isaretlenir.
- Gerekce:
  - D-115 kapanisinda yerel release runner yesildi ancak Actions workflow eksik kaldi; faz-gate dokumantasyon tutarliligi.
- Etki:
  - `.github/workflows/smoke-tests.yml`, `docs/operations/release-readiness.md`, `implementation/phases/phase-15.md`, `phase-15-scheduler-queue.md`, `implementation/11-status-2026-07-27.md`, `implementation/README.md`.

## 2026-07-28 - D-115 - Phase 15 Gate Closure (Scheduler / Queue / Manifest)

- Durum: accepted
- Karar:
  - Faz 15 resmi kapanis: tracker `done`, tamamlanma 2026-07-28.
  - Gate kriterleri: schedule/queue komut seti (D-111, D-112), horizon/php_worker manifest sinirlari (D-113), `schedule cron-install` (D-114), komut dokumanlari, `tests/phase15_scheduler_queue_smoke.sh` release zincirinde, `./tests/run_smoke_suite.sh --release` yesil.
  - Kapsam disi (Faz 15+ backlog): `plume.yml` v2 ve docker-lite derinlestirme — [phase-15-backlog-plume-yml-dockerlite.md](phases/phase-15-backlog-plume-yml-dockerlite.md).
- Gerekce:
  - AGENTS.md faz-gate: test + dokumantasyon + karar kaydi; operasyonel scheduler/queue MVP hedefi karsilandi.
- Etki:
  - `implementation/phase-tracker.md`, `implementation/phases/phase-15.md`, `phase-15-scheduler-queue.md`, `implementation/11-status-2026-07-28.md`, `README.md`, `implementation/05-decision-log.md`.

## 2026-07-28 - D-114 - Phase 15 Plume-Managed Scheduler Crontab Install

- Durum: accepted
- Karar:
  - Alt komut: `plume schedule cron-install` (`--path=`, `--dry-run`, `--remove`); kullanici crontab (asla root).
  - Tek satir: `* * * * * cd <project> && <php> artisan schedule:run >> /dev/null 2>&1 # plume-laravel-schedule-cron`; PHP cozumleme D-112 ile ayni (`PLUME_PHP_BIN` / site surumu).
  - Kurulum: `crontab -l` birlestirme; marker varsa idempotent exit `0`; kaldirma yalnizca marker iceren satirlar.
  - Hermetik test: `PLUME_CRONTAB_FILE` gecici dosya (gercek crontab dokunulmaz).
  - `schedule status` INFO: `cron-install` onerisi; `CRON_HINT` generic `php` kalir.
- Gerekce:
  - Phase 15 ucuncu dilim: Herd-benzeri tek komutla dakikalik scheduler; MVP manuel kopya-yapistir yerine guvenli merge.
- Etki:
  - `lib/commands/schedule_queue.sh`, `lib/commands/help.sh`, `docs/commands/schedule.md`, `implementation/phases/phase-15.md`, `phase-15-scheduler-queue.md`, `implementation/05-decision-log.md`, `tests/phase15_scheduler_queue_smoke.sh`.

## 2026-07-28 - D-113 - Phase 15 Tracker and Horizon Manifest Limits

- Durum: accepted
- Karar:
  - Faz 15 resmi checklist: `implementation/phases/phase-15.md`; tracker satiri `in-progress`.
  - `services.yml` icin horizon / php_worker / supervisor: yalnizca env toggle; native `provision --from-manifest` yok; docker-lite `laravel-horizon` eslemesi dokumante.
- Gerekce:
  - Phase 15 ikinci dilim sonrasi manifest belirsizligi giderilir; native'de Horizon icin supervisor beklentisi netlesir.
- Etki:
  - `docs/operations/services-manifest.md`, `implementation/phase-tracker.md`, `implementation/phases/phase-15.md`, `phase-15-scheduler-queue.md`.

## 2026-07-28 - D-112 - Phase 15 Schedule List / Run-Once / Queue Failed List

- Durum: accepted
- Karar:
  - `plume schedule list` ve `plume schedule run-once`: proje cozumleme D-111 ile ayni; `php artisan schedule:list` / `schedule:run --no-interaction`; site PHP surumu veya `PLUME_PHP_BIN`; plume crontab install yok.
  - `run-once --dry-run`: yalnizca planlanan shell satirini yazar; basarili `run-once` sonrasi crontab `not-configured` ise `CRON_HINT` INFO.
  - `plume queue list`: `php artisan queue:failed`; Horizon env aciksa `horizon:status` / `services status horizon` dokuman + INFO (ayri Artisan cagrisi yok).
  - Exit: plume hatalari `2`; Artisan basarisizligi `1` (passthrough).
  - Smoke: mock `php` + genisletilmis `phase15_scheduler_queue_smoke.sh`.
- Gerekce:
  - Phase 15 ikinci dilim: Artisan sarmalayicilari ve operasyonel test; tam cron install sonraki checklist maddesinde.
- Etki:
  - `lib/commands/schedule_queue.sh`, `lib/commands/help.sh`, `docs/commands/schedule.md`, `docs/commands/queue.md`, `implementation/phases/phase-15-scheduler-queue.md`, `implementation/05-decision-log.md`, `tests/phase15_scheduler_queue_smoke.sh`.

## 2026-07-27 - D-111 - Phase 15 Scheduler/Queue Status MVP

- Durum: accepted
- Karar:
  - Ayri ust duzey komutlar: `plume schedule status`, `plume queue status` (`lib/commands/schedule_queue.sh`); `ops` namespace yok (mevcut `sync`/`status` router deseni).
  - Proje yolu cozumleme sirasi: `--path=` → kayitli site (CWD prefix) → CWD'de `artisan` → aktif mod workspace + `artisan`.
  - Scheduler MVP: kullanici crontab taramasi (`schedule:run`, istege bagli `# plume-laravel-schedule-cron` marker); otomatik cron install yok; `CRON_HINT` her zaman `* * * * * cd ... && php artisan schedule:run`.
  - Queue MVP: `.env` `QUEUE_CONNECTION`/`QUEUE_DRIVER`; `PLUME_HORIZON_ENABLED` / supervisor / php_worker env + `plume_services_display_status_line`; native'de tam supervisor kurulumu yok — durum + `./plume.sh services up horizon` ipucu.
  - Release smoke: `tests/phase15_scheduler_queue_smoke.sh` (`run_smoke_suite.sh --release`).
- Gerekce:
  - Phase 15 ilk dilim: operasyonel gorunurluk ve Herd-benzeri yonlendirme; worker install/compose genisletmesi sonraki checklist maddelerinde.
- Etki:
  - `lib/bootstrap.sh`, `lib/commands/help.sh`, `docs/commands/schedule.md`, `docs/commands/queue.md`, `docs/commands/README.md`, `implementation/phases/phase-15-scheduler-queue.md`, `tests/phase15_scheduler_queue_smoke.sh`, `tests/run_smoke_suite.sh`.

## 2026-07-27 - D-110 - macOS Local Dev Ergonomics (Extension Sync + TCC Path Warnings)

- Durum: accepted
- Karar:
  - Gunluk macOS gelistirme icin varsayilan oneri: `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=target` (`templates/native-local.env.example`, `.env.example` yorumlari, `docs/operations/local-dev-macos.md`).
  - `matrix` profili coklu PHP surumu senkronu icin kalir; prod preset `target` ile hizali.
  - `site add` / basarili `site update`: TCC-duyarli path icin her zaman `plume_warn` + `~/Sites/<basename>` ve `init permissions --interactive` ipucu (JSON: `warnings`).
  - `site check --json`: `data.tcc_risk` boolean; TCC metni `warnings` ve text ciktida `tcc_risk` / `tcc_hint`.
- Gerekce:
  - Tam extension matrix sync gunluk `services up php` icin yavas/pecl hatali; Herd-benzeri akista tek hedef surum yeterli.
  - Desktop/Documents/Downloads altindaki tunnelion gibi sitelerde TCC riski komut ciktisinda kaybolmamali.
- Etki:
  - `lib/common/macos_permissions.sh`, `lib/commands/site.sh`, `docs/operations/local-dev-macos.md`, `docs/contracts/cli-output-contract.md`, `tests/phase11_native_env_presets_smoke.sh`.

## 2026-07-27 - D-109 - Native Mailpit Host Provision (Homebrew) + Doctor Port-80 UX

- Durum: accepted
- Karar:
  - `mailpit` native host provision: macOS Homebrew `brew install mailpit` + `brew services start mailpit` (`plume_native_host_provision_*`).
  - `services up mailpit` / `install mailpit` mailpit icin global `PLUME_NATIVE_HOST_PROVISION` olmadan da brew yolunu calistirir (`plume_native_host_provision_service_wants`).
  - Linux/apt: desteklenmez; `services up mailpit` ve manifest provision acik WARN + exit 2; docker-lite veya manuel kurulum.
  - `services provision --from-manifest`: `mailpit.enabled: true` icin brew kurulum/start (macOS).
  - `doctor web`: Homebrew 8080 + registry port 80 iken `listener-80` / `sites-port80` WARN satirlarina `services web sync-config --reload` + `site check` ipucu.
- Gerekce:
  - Herd parity: gelistirme mail yakalama native stack'te tek komutla acilabilmeli; portsuz URL / 8080 karisikliginda tek satirlik duzeltme yolu.
- Etki:
  - `lib/services/native_host_provision.sh`, `lib/common/services_manifest.sh`, `lib/services/registry.sh`, `lib/commands/doctor.sh`, `docs/commands/services.md`, `docs/commands/services-provision.md`, `docs/operations/services-manifest.md`, `docs/commands/services-web.md`, `tests/phase12_native_host_provision_mailpit_smoke.sh`, `implementation/phases/phase-15-scheduler-queue.md` (backlog stub).

## 2026-07-27 - D-108 - Manifest `provision.on_first_run` (One-Shot Host Bootstrap)

- Durum: accepted
- Karar:
  - `services.yml` → `provision.on_first_run: true` iken, native modda ve `PLUME_STATE_DIR/on_first_run_provision.done` yokken bir kez `services provision --from-manifest` calisir.
  - Tetikleyiciler: ilk anlamli CLI bootstrap (`help`/`version`/`init` haric) veya `init host` (`--apply` yokken `maybe`; `--apply` dogrudan provision + bayrak).
  - Manuel `services provision --from-manifest` veya `--apply` basarili olunca bayrak yazilir (idempotent).
  - `PLUME_SKIP_ON_FIRST_RUN_PROVISION=true` smoke/test opt-out; `provision.interactive: false` → `PLUME_NONINTERACTIVE` (D-100).
- Gerekce:
  - Greenfield kullanicilar `init host --apply` adimini atlayabiliyor; sablon `on_first_run: true` ile stack kurulumu otomatiklestirilmeli.
- Etki:
  - `lib/common/services_manifest.sh`, `lib/bootstrap.sh`, `lib/commands/init_host_onboarding.sh`, `docs/operations/services-manifest.md`, `tests/phase11_services_manifest_smoke.sh`.

## 2026-07-26 - D-107 - Homebrew FPM Pool `listen` Aligned Before `brew services start`

- Durum: accepted
- Karar:
  - Native macOS `plume_native_php_start_fpm_service` (brew), `brew services start` oncesi `plume_native_php_ensure_fpm_listen` calistirir:
    - `www.conf` (veya test: `PLUME_PHP_FPM_WWW_CONF`) icindeki `listen` Plume canonical unix yolu ile eslesmiyorsa guncellenir (`plume_sites_php_canonical_homebrew_socket`, or. `/opt/homebrew/var/run/php@8.2-fpm.sock`).
    - Idempotent: zaten dogruysa no-op; ilk degisiklikte `www.conf.plume-bak` yedegi.
  - Baslatma sonrasi `plume_native_php_verify_fpm_after_brew_start`: canonical socket `-S` ile dogrulanir; yoksa php-fpm log tail + `exit 2` (or. `127.0.0.1:9000` port cakismasi).
  - `PLUME_PHP_NATIVE_INSTALL_DRIVER=mock` ensure/verify atlar (smoke uyumu); hermetik listen smoke: `PLUME_PHP_FPM_ENSURE_LISTEN_SOCKET` + `PLUME_PHP_FPM_WWW_CONF`.
- Gerekce:
  - Homebrew varsayilan pool `listen = 127.0.0.1:9000`; coklu surumde port cakismasi FPM'i dusurur, site ise `php@8.2-fpm.sock` bekler.
- Etki:
  - `lib/services/registry.sh`, `docs/commands/services.md`, `docs/commands/php.md`, `docs/commands/site.md`, `tests/phase11_native_php_ensure_fpm_listen_smoke.sh`.

## 2026-07-26 - D-106 - Native `services up php` Starts Versioned Homebrew FPM

- Durum: accepted
- Karar:
  - Native `plume_service_start_native` PHP yolunda binary/auto-provision sonrasi host FPM baslatilir:
    - macOS brew: `brew services start php@<major.minor>` (`plume_native_php_brew_service_name`; kurulu formul yoksa ayni ad denenir; default surum + kurulu `php` formulunde `php` servis adi).
    - Linux apt: `systemctl start php<major.minor>-fpm`.
  - `services down php` / `php82` hedef surumun FPM servisini durdurur; diger surumleri etkilemez.
  - `PLUME_PHP_NATIVE_INSTALL_DRIVER=mock` gercek brew/systemd cagirmaz (smoke uyumu).
- Gerekce:
  - `services up php82` yalnizca state/log yazip `brew services start php@8.2` calistirmiyordu; site nginx `php@8.2-fpm.sock` beklerken FPM ayakta kalmiyordu.
- Etki:
  - `lib/services/registry.sh`, `docs/commands/services.md`, `tests/phase11_services_up_php_native_brew_start_smoke.sh`.

## 2026-07-26 - D-105 - Non-Default Native PHP Upstream Must Not Alias Default TCP Pool

- Durum: accepted
- Karar:
  - Native `plume_sites_php_upstream_for_version` resolver sırası genişletildi:
    1. env override (`PLUME_NATIVE_PHP_FPM_UPSTREAM`, `..._<major><minor>`)
    2. mevcut unix socket (`-S` ile)
    3. kurulu pool config `listen` (default sürüm veya paylaşılan `127.0.0.1:9000` dışı)
    4. default dışı sürüm + Homebrew `php@X.Y` kurulu → canonical `unix:.../php@X.Y-fpm.sock` (paylaşılan TCP havuzuna düşme)
    5. default sürüm → `127.0.0.1:9000` fallback
  - Homebrew’da çoğu `php-fpm` pool’u `listen = 127.0.0.1:9000` kullanır; yalnızca default PHP için bu upstream kabul edilir.
- Gerekce:
  - Site kaydında `php_version: 8.2` iken snippet header doğru olsa bile `fastcgi_pass 127.0.0.1:9000` çalışan default pool’a (ör. php@8.3) gider; sessiz yanlış runtime.
- Etki:
  - Per-version native routing daha güvenli; php@8.2 için `services up php82` + pool’un unix socket dinlemesi (veya `--php-upstream`) beklenir.
  - Smoke: `tests/phase11_site_php_upstream_resolver_smoke.sh`

## 2026-07-26 - D-104 - Full Registry `services.yml` Mapping (Schema v1 Extension)

- Durum: accepted
- Karar:
  - `templates/services.yml.example` tum `plume_service_names` kayit servislerini kapsar (web/php/database ozel bloklari + registry toggle/version).
  - Tek env esleme tablosu: `plume_services_manifest_env_mapping_rows` (`lib/common/services_manifest.sh`); `plume_service_env_key` / `plume_service_version_env_key` ile hizali.
  - YAML okuma: blok scalar + inline `{ enabled: true, version: "16" }`; eksik anahtar = defaults (geriye uyumlu).
  - `services manifest show`: her kayit servisi icin `effective_<service>_enabled` ve (varsa) `effective_<service>_version` satirlari.
  - `services provision --from-manifest`: native desteklenen paketler (web, mariadb, mysql, redis) + manifest `php.versions` icin best-effort host PHP kurulumu; diger enabled servisler icin uyari (docker/manual).
  - Laradock-only `workspace` / `php-fpm`: ornek YAML yorumlari; native loader no-op.
- Gerekce:
  - D-103 MVP yalnizca web/php/database/redis idi; tek YAML ile tum PLUME_*_ENABLED yonetimi adapter ve greenfield kurulum icin gerekli.
- Etki:
  - `lib/common/services_manifest.sh`, `templates/services.yml.example`, `docs/operations/services-manifest.md`, `docs/commands/services-provision.md`, `docs/operations/ai-assisted-development.md`, `tests/phase11_services_manifest_full_smoke.sh`, `implementation/05-decision-log.md`.

## 2026-07-26 - D-103 - Native `services.yml` Stack Manifest (MVP)

- Durum: accepted
- Karar:
  - Merkezi native stack manifest: `~/.config/plume/services.yml` (override: `PLUME_SERVICES_MANIFEST_FILE`); repo sablonu `templates/services.yml.example`.
  - Birlesme: `plume_load_defaults` → `plume_services_manifest_apply` → `plume_load_env` → `plume_load_defaults` (php.env); `.env` ayni anahtarlarda YAML uzerine yazar.
  - Loader: `lib/common/services_manifest.sh`; bootstrap sirasi `lib/bootstrap.sh` icinde guncellendi.
  - Komutlar: `init host` manifest bootstrap + `--apply`; `services manifest show`; `services provision --from-manifest [--dry-run]`.
  - `host.env` makine kimligi icin kalir; servis toggle manifest + env katmaninda.
- Gerekce:
  - Laradock benzeri tek YAML ile greenfield native kurulum; mevcut yalnizca `.env` kullanicilari etkilenmez (manifest yok = no-op).
- Etki:
  - `lib/common/services_manifest.sh`, `lib/bootstrap.sh`, `lib/config/defaults.sh`, `lib/commands/init_host_onboarding.sh`, `lib/commands/services.sh`, `templates/services.yml.example`, `docs/operations/services-manifest.md`, `docs/commands/services-provision.md`, `docs/operations/first-run-onboarding.md`, `docs/operations/env-contract.md`, `tests/phase11_services_manifest_smoke.sh`.

## 2026-07-26 - D-102 - AI Development Prompt Record

- Durum: accepted
- Karar:
  - Kalici AI/human pair-programming baglami: `docs/operations/ai-assisted-development.md` (session bootstrap, smoke stratejisi, pre-PR checklist).
  - Cursor always-on kural: `.cursor/rules/plume-smoke-and-agents.mdc`.
  - `AGENTS.md` §5 ve README Test bolumu bu rehbere link verir.
- Gerekce:
  - Smoke suite ve hermetic test duzeltmeleri (PATH, pipefail, nginx strict, macOS TCC) oturumlar arasi unutuluyordu.
- Etki:
  - Yeni sohbetlerde copy-paste bootstrap; agent kurallari smoke/doc yukumluluklerini hatirlatir.

## 2026-07-26 - D-101 - Unified Smoke Suite Entrypoint

- Durum: accepted
- Karar:
  - Tek yerel/CI hizalama scripti: `tests/run_smoke_suite.sh` (`--release` default, `--ci`, `--phase11-full`, `--all`; `--linux` / `PLUME_RUN_LINUX_TESTS=1` phase3 Linux matrix icin).
  - `--release` ve `--ci` ayni adim listesini calistirir (`.github/workflows/smoke-tests.yml`); `*e2e_matrix*` aggregator’lar `--all` icinde haric tutulur (cift calisma onlenir).
- Gerekce:
  - README, runbook ve Actions farkli komut listeleri sunuyordu; yayin oncesi tek fail-fast zincir gerekiyordu.
- Etki:
  - Release readiness ve README bu script’e yonlendirilir; mevcut tekil smoke scriptleri degismeden kalir.

## 2026-07-26 - D-100 - Interactive macOS Permission and Host Install Prompts

- Durum: accepted
- Karar:
  - Yeni modul: `lib/common/macos_permissions.sh` — TTY/`PLUME_INTERACTIVE` algisi, TCC menu (FDA ac, ~/Sites onerisi, devam/iptal), brew install onay (`PLUME_NATIVE_HOST_PROVISION`), istege bagli sudo nginx port 80 onay.
  - TCC path kapsami: Desktop, Documents, **Downloads** (`plume_sites_path_is_macos_tcc_sensitive`).
  - Hook: `site add`, `site update --path`, `init host`, `init onboarding`, `init permissions --interactive`, site auto-provision web, `doctor web`/`doctor php` WARN satirinda `init permissions --interactive` ipucu.
  - CI: `PLUME_NONINTERACTIVE=1` ve global `--yes` (`PLUME_ASSUME_YES`) promptlari atlar; TTY yokken install onaysiz devam (mevcut smoke uyumu).
  - FDA otomatik grant **yok** — yalnizca aciklama, System Settings acma, Finder reveal.
- Gerekce:
  - Desktop alti projeler (orn. tunnelion) TCC yuzunden manuel macOS adimlari gerektiriyor; Plume rehberlik etmeli, dürüst TCC siniri dokümante edilmeli.
- Etki:
  - `lib/common/macos_permissions.sh`, `lib/bootstrap.sh`, `lib/common/sites.sh`, `lib/commands/site.sh`, `lib/commands/init_host_onboarding.sh`, `lib/services/native_host_provision.sh`, `lib/services/native_web_nginx_config.sh`, `lib/commands/doctor.sh`, `docs/operations/macos-permissions.md`, `docs/commands/init-permissions.md`, `docs/commands/site.md`, `docs/operations/first-run-onboarding.md`, `tests/phase11_macos_permissions_smoke.sh`.

## 2026-07-26 - D-099 - macOS Full Disk Access Onboarding UX (CLI, Not an App)

- Durum: accepted
- Karar:
  - Plume `./plume.sh` / `plumectl` bir GUI uygulamasi degildir; FDA ve dokumanlarda **Plume app veya plume.sh eklenmez**.
  - `init onboarding` / `doctor onboarding`: varsayilan cikti nginx ve php-fpm binary yollarini cozumler (`command -v`, `brew --prefix`, `plume_php_find_fpm_bin`); istege bagli Terminal/iTerm yolu.
  - `--fix`: yalnizca guvenli host duzeltmeleri (Homebrew `brew services start nginx` + kurulu PHP formul); **System Settings otomatik acilmaz**.
  - `--open-settings`: acik FDA pane acma (onceki `--fix` davranisi kaldirildi).
  - `init permissions --open`: acmadan once binary listesi + uyari; `--reveal` Finder'da nginx bin dizini.
  - Dev/repo tespiti (`PLUME_REPO_ROOT` veya `ROOT_DIR` + `.git` + `plume.sh`): Desktop disi path onerisi, FDA opsiyonel vurgusu.
- Gerekce:
  - Kullanicilar `init onboarding --fix` ile acilan FDA ekraninda eklenecek "Plume" gormuyor; TCC asil olarak nginx/php-fpm daemon binary'lerini etkiler.
- Etki:
  - `lib/commands/init_host_onboarding.sh`, `lib/commands/help.sh`, `docs/commands/init-onboarding.md`, `docs/commands/init-permissions.md`, `docs/operations/first-run-onboarding.md`, `tests/phase11_host_onboarding_smoke.sh`.

## 2026-07-26 - D-098 - Host Profile Persistence and First-Run Onboarding

- Durum: accepted
- Karar:
  - Makine kimligi `~/.config/plume/host.env` (`key=value`) olarak persist edilir; alanlar: `os`, `os_version`, `arch`, `package_manager`, `web_driver_hint`, `nginx_http_port_detected`, `homebrew_nginx`, `state_dir`, `detected_at`; Windows icin `native_support_note`.
  - Komutlar: `init host`, `init onboarding [--fix] [--open-settings]`, `init permissions [--open] [--reveal]`; doctor alias: `doctor host`, `doctor onboarding [--fix] [--open-settings]`.
  - `PLUME_AUTO_HOST_BOOTSTRAP=true` (varsayilan): profil yoksa ilk CLI girisinde idempotent tespit (dosya varsa no-op).
  - Windows: yalnizca profil; tam native nginx/site publish bu kararda kapsam disi.
- Gerekce:
  - Kullanicilar TCC, Homebrew 8080 ve config yollarini parca parca ogrenmesin; mevcut `plume_detect_os`, `doctor web` (`macos-site-tcc`), `services web sync-config` ile hizalanmis tek onboarding yolu.
- Etki:
  - `lib/common/host_profile.sh`, `lib/common/os.sh`, `lib/commands/init_host_onboarding.sh`, `lib/bootstrap.sh`, `docs/operations/first-run-onboarding.md`, `docs/commands/init-*.md`, test smoke.

## 2026-07-26 - D-097 - Nginx Laravel PHP Location (Front Controller + macOS TCC)

- Durum: accepted
- Karar:
  - Native nginx site snippet'inde PHP location Laravel standartina cekildi: `try_files $uri =404`, `fastcgi_split_path_info`, `include fastcgi_params` sonra `SCRIPT_FILENAME` (`$realpath_root$fastcgi_script_name`).
  - macOS TCC: Desktop/Documents altindaki site path'leri icin `doctor web` (`macos-site-tcc`) ve `doctor php` (`MACOS_TCC`) WARN; `site.md` troubleshooting bolumu.
- Gerekce:
  - Front controller internal redirect sonrasi bazi kurulumlarda bos/yanlis SCRIPT_FILENAME; ayrica Desktop path'lerinde php-fpm "No input file specified" / Operation not permitted ayirt edilmeli.
- Etki:
  - `lib/common/sites.sh`, `lib/commands/doctor.sh`, `lib/commands/site.sh`, `docs/commands/site.md`, `docs/commands/status-health-logs.md`, `tests/phase11_site_nginx_php_front_controller_smoke.sh`.

## 2026-07-26 - D-096 - Per-Site TLS Disable via `site update --clear-cert`

- Durum: accepted
- Karar:
  - Site bazlı HTTPS kapatma için `site update <id> --clear-cert` eklendi (`--tls=false` alias).
  - Kayıttan `cert_id` ve `https_port` alanları kaldırılır; publish render `tls_enabled=false` ile HTTP-only snippet üretir (nginx/apache2 redirect bloğu yok).
  - Sertifika artifact'leri `$(plume_state_dir)/certs/<id>/` altında kalır; yeniden `--cert-id` ile bağlanabilir.
  - `site add` üzerinde `--clear-cert` reddedilir; `--clear-cert` ile dolu `--cert-id` birlikte kullanılamaz.
- Gerekce:
  - Yerel geliştirmede HTTP→HTTPS redirect istenmeyen durumlarda site kaydını silmeden TLS'i devre dışı bırakmak gerekir.
  - Ayrı `tls_enabled` yaml alanı yerine mevcut site komut flag desenine uygun explicit CLI tercih edildi.
- Etki:
  - `lib/commands/site.sh`, `docs/commands/site.md`, `docs/commands/security.md`, `tests/phase11_site_clear_cert_smoke.sh`.

## 2026-07-26 - D-095 - sync-config --reload: plume_sites_reload_native wiring

- Durum: accepted
- Karar:
  - `plume_native_nginx_reload_for_http_port` dogrudan `plume_sites_reload_native nginx` cagirir (`sites.sh`, bootstrap sirasinda yuklenir).
  - Yanlis/eksik helper adi (`plume_sites_reload_native_server`) kaldirildi; basarisiz reload sonrasi `brew services restart nginx` fallback ve acik hata mesaji.
- Gerekce:
  - `services web sync-config --reload` ana config patch sonrasi nginx'i yenilemeden birakiyordu (`nginx reload helper unavailable`).
- Etki:
  - `lib/services/native_web_nginx_config.sh`, `docs/commands/services-web.md`, smoke: `tests/phase11_services_web_sync_config_reload_smoke.sh`.

## 2026-07-26 - D-094 - Native Nginx Main Config Port Management (Homebrew 8080 → 80)

- Durum: accepted
- Karar:
  - Homebrew nginx formulü build sirasinda `listen 80` → `8080` yapar (root gerektirmemek icin; kaynak: `homebrew-core` `Formula/n/nginx.rb`).
  - Opt-in env: `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG`, `PLUME_NATIVE_NGINX_HTTP_PORT` (default `80`), opsiyonel `PLUME_NATIVE_NGINX_MAIN_CONF`.
  - Yeni komutlar: `services web sync-config`, `services web port <n>`, `doctor web fix-ports` (aynı sync helper).
  - Sync: yedek + ana `nginx.conf` listen patch + `nginx -t` + istege bagli reload; macOS port 80 icin sudo brew services mesaji.
  - `plume_sites_effective_http_port`: ana config listen okunur; 80 ise site render 8080'e zorlanmaz (`PLUME_NATIVE_HOMEBREW_HTTP_PORT` explicit override korunur).
- Gerekce:
  - `http://myapp.test` (portsuz) ile Homebrew varsayilan 8080 uyumsuzlugu; Plume'un snippet disinda ana nginx erisimini de yonetmesi gerekiyor.
- Etki:
  - `docs/commands/services-web.md`, env-contract, site.md, status-health-logs; smoke: `tests/phase11_services_web_sync_config_smoke.sh`.

## 2026-07-26 - D-093 - Doctor Web: Native Webserver and Port Diagnostics

- Durum: accepted
- Karar:
  - Yeni alt komut: `doctor web [--mode=...] [--strict]`.
  - Native modda `PLUME_WEB_SERVER_DRIVER`, binary yolu, brew/systemd servis durumu, `listener-effective` (registry + `plume_sites_effective_http_port`), port 80/443 dinleyicileri, nginx strict include hedefi vs plume cache karsilastirmasi ve registry `port: 80` site uyarisi.
  - Kritik FAIL + `--strict` → exit code `2` (`doctor php` ile ayni disiplin).
- Gerekce:
  - `myapp.test` / ERR_CONNECTION_REFUSED vakalarinda web servisi calisiyor mu ve port 80 mi 8080 mi netlestirilmeli; `site check` tek basina yeterli degil.
- Etki:
  - `docs/commands/status-health-logs.md` guncellendi; smoke: `tests/phase11_doctor_web_smoke.sh`.

## 2026-07-25 - D-092 - Site Check: Effective Port and Open URLs

- Durum: accepted
- Karar:
  - `site check` ciktisina `effective_http_port`, `url_http`, `url_https` (cert varsa), `access_hint` eklendi.
  - Registry `port: 80` + Homebrew nginx `8080` iken kullaniciya acik URL gosterilir; port 80 dinlenmedigi icin `http://domain` (portsuz) basarisiz olur.
- Gerekce:
  - ERR_CONNECTION_REFUSED teshisi registry portu ile gercek listen portu karistirilmasindan kaynaklaniyordu.
- Etki:
  - Adapter `--json` `site check` semasi genisledi (non-breaking additive fields + opsiyonel warnings).

## 2026-07-25 - D-091 - Native Site Publish: Strict on Reload, Homebrew Port, PHP Upstream

- Durum: accepted
- Karar:
  - `PLUME_SITE_NGINX_STRICT_ON_RELOAD=true` (default): `site publish --reload` snippet'i Homebrew `nginx/servers/` altina yazar.
  - Homebrew `servers/` dizini yoksa olusturulur.
  - Site `port: 80` + macOS Homebrew nginx `listen 8080` ise render portu otomatik 8080 (`plume_sites_effective_http_port`).
  - Native PHP upstream fallback: `127.0.0.1:9000` (docker `php-fpm:9000` yerine).
  - Nginx PHP location: `$realpath_root` (Laravel uyumu).
- Gerekce:
  - Publish cache ile calisan nginx ayrimi yuzunden domain erisilemiyordu.
- Etki:
  - `--reload` ile vhost gercek nginx'e baglanir; HTTPS cert'li siteler `:4443` kullanir.

## 2026-07-25 - D-090 - Site Publish Auto-Provision Web Runtime on Reload

- Durum: accepted
- Karar:
  - Yeni env: `PLUME_SITE_AUTO_PROVISION_WEB=true` (default).
  - Native `site publish --reload` oncesi `plume_sites_native_ensure_web_runtime` calisir:
    - nginx binary yoksa host provision ile `web` kurulumu + start (brew/apt).
    - binary var ama brew service duruyorsa `brew services start nginx`.
  - `PLUME_SITE_AUTO_PROVISION_WEB=false` ile davranis eski haline (sadece uyar, kurulum yapmaz).
- Gerekce:
  - Kullanici beklentisi: Plume site publish ile birlikte web sunucusunu da yonetmeli; nginx yokken reload uyarisi yeterli degil.
- Etki:
  - Ilk `--reload` macOS'ta Homebrew ile nginx kurabilir (ag erisimi gerekir).

## 2026-07-25 - D-089 - Backlog: plume.yml v2 and Docker-Lite Unfreeze (Deferred)

- Durum: accepted
- Karar:
  - `plume.yml` genis manifest (site + enabled services + php version) Phase 15+ backlog olarak kalir; phase-4 baseline (`mode` cozumlemesi) korunur.
  - Docker-lite `beta-frozen` durumu korunur; unfreeze ayri faz olarak planlanir (compose zorunlulugu, image slimming).
- Gerekce:
  - Phase 12-14 odagi native host provisioning, deploy apply ve release/CI stabilizasyonu.
- Etki:
  - Manifest ve docker-lite derinlestirmesi icin net karar kaydi; scope creep engellenir.

## 2026-07-25 - D-088 - Phase 14: CI Smoke Matrix + Golden JSON Baseline

- Durum: accepted
- Karar:
  - PR workflow: `phase10_e2e_matrix_smoke.sh` (phase 11 runner dahil) + `phase14_golden_json_smoke.sh`.
  - Manual release workflow release job oncesi ayni smoke zincirini calistirir.
  - Golden snapshot testleri ilk kapsam: `prereq check --json`, `services supported --json`, `mode current --json`.
- Gerekce:
  - Adapter-readiness ve release no-go kurallari otomasyona baglanmali.
- Etki:
  - Regresyonlar PR seviyesinde yakalanir; CLI contract kirilmalari erken gorulur.

## 2026-07-25 - D-087 - Phase 13: Deploy Apply Baseline (Reconcile + Health Gate)

- Durum: accepted
- Karar:
  - `deploy apply` implement edildi: opsiyonel pre-deploy backup, `doctor check --deep`, `services update`, `monitor summary --strict`.
  - `--dry-run`, `--skip-backup`, `--skip-health` flag'leri eklendi.
  - Kritik aksiyon `--yes deploy apply` ile onaylanir.
- Gerekce:
  - `deploy plan` zincirindeki bos halka kapatilir; rollback/failback ile uyumlu operate journey saglanir.
- Etki:
  - Production ops dokumanlari ve smoke testleri guncellenir.

## 2026-07-25 - D-086 - Phase 12: Native Host Provisioning Opt-In (`PLUME_NATIVE_HOST_PROVISION`)

- Durum: accepted
- Karar:
  - Varsayilan davranis korunur: state/port orchestration (simulate).
  - `PLUME_NATIVE_HOST_PROVISION=true` iken `@core/@web/@db` servisleri icin gercek host kurulum/start/stop:
    - `nginx`, `apache2`, `mariadb`, `mysql`, `redis` (brew/apt; dnf best-effort).
  - PHP kurulumu mevcut native PHP driver ile devam eder (ayri env gerektirmez).
- Gerekce:
  - Mevcut smoke testleri kirilmadan gercek host provisioning acilabilir.
- Etki:
  - Herd-benzeri tek komut deneyimi opt-in ile saglanir; phase 12 smoke state modunda calisir.

## 2026-07-25 - D-085 - Phase 11 Closure: Native Adapter Contract Parity Completed

- Durum: accepted
- Karar:
  - Phase 11 gate maddeleri tamamlandi; faz `done` olarak kapatildi.
  - Release matrix'e `tests/phase11_e2e_matrix_smoke.sh` eklendi; README ve parity checklist senkronlandi.
  - Open risk'ler Phase 12+ (launchd/systemd edge-case, adapter JSON farklari) devredildi.
- Gerekce:
  - Faz-gate disiplini (test + dokuman + karar kaydi) tamamlanmali.
- Etki:
  - Tracker ve dokumanlar gercek olgunluk seviyesini yansitir.

## 2026-07-25 - D-084 - Native Nginx Reload Detection Includes Homebrew Prefix

- Durum: accepted
- Karar:
  - Native reload/validate akisi, `nginx` binary'sini PATH'te bulamazsa Homebrew prefix altindaki `bin/nginx` veya `sbin/nginx` yollarini dener.
- Gerekce:
  - macOS sistemlerinde Homebrew kurulu olsa bile `nginx` her zaman shell PATH'ine ekli olmuyor.
  - Reload dedektoru PATH bagimliligina takilmadan daha dayanıklı olmali.
- Etki:
  - `site publish --reload` native modda Homebrew nginx kurulumlarinda daha az false-negative verir.

## 2026-07-25 - D-083 - Site Modes Registry View and Mode Drift Cleanup

- Durum: accepted
- Karar:
  - `plumectl site modes` komutu eklendi.
  - Bu komut, site kayitlarinin mode bazli toplu gorunumunu verir.
  - `site update <id> --mode=<mode>` sonrasi eski mode'a ait cache/snippet artefact'lari otomatik temizlenir.
- Gerekce:
  - Mode gecislerinde eski registry/konfigurasyon izlerinin kalmasi karisikliga yol aciyordu.
  - Adapter-ready bir sistemde mevcut mode durumunun toplu ve hizli gorunmesi gerekir.
- Etki:
  - `site modes` drift kontrolu icin standart gorunum olur.
  - Mode gecisleri disinda eski snippet dosyalari sistemde birikmez.

## 2026-07-25 - D-082 - Site Update Mode Override Contract

- Durum: accepted
- Karar:
  - `site update <id> --mode=<mode>` komutu site kaydinin mode alanini override edebilir.
  - Sonraki `site publish` ve `site remove` isleri bu yeni mode'a gore calisir.
- Gerekce:
  - Kullanici bir siteyi native, docker-lite ve laradock-bridge arasinda tasiyabilmeli.
  - Mode degisimi ayri bir yeniden kayit akisi gerektirmemeli.
- Etki:
  - `site update --mode=native` ile kayitli site native reload pipeline'ina gecirilebilir.
  - Publish dispatch mode'u artık güncel kayıt mode'una gore belirler.

## 2026-07-25 - D-081 - Site List Tablo Layout Stabilization

- Durum: accepted
- Karar:
  - `site list` text cikti layout'u sabitlendi.
  - Kolon sirasi `ID, SERVER, PHP, PORT, HTTPS, CERT, STATUS, DOMAINS, PATH` olarak standardize edildi.
  - `PATH` kolonu en sonda tutulacak.
  - Header ve satirlar ayni width renderer üzerinden formatlanacak.
- Gerekce:
  - Uzun path degerleri tabloyu kaydiriyordu.
  - Adapter-ready text output icin kolon hizasi ve sirasi parse edilebilir kalmali.
- Etki:
  - `site list` preview regresyonlari daha erken yakalanacak.
  - Dokuman ve smoke testler bu layout'u referans alacak.

## 2026-03-06 - D-001 - 3 Modlu Birlesik Mimari

- Durum: accepted
- Karar:
  - Plume tek utility olacak, 3 calisma modu sunacak:
    - native
    - docker-lite
    - laradock-bridge
- Gerekce:
  - Farkli ekip ve altyapi olgunlugu seviyelerini tek aracta toplamak
  - Laradock bagimliligini optional hale getirmek
- Etki:
  - Engine abstraction zorunlu
  - Test matrisi 3x buyur

## 2026-03-06 - D-002 - Config as Code (YAML)

- Durum: accepted
- Karar:
  - Lokal + production senaryolari YAML sozlesmesi uzerinden tanimlanacak
- Gerekce:
  - Tek kaynaktan tekrar edilebilir kurulum
  - AI ve insan contributor icin baglami acik tutma
- Etki:
  - Schema validation katmani gerekir
  - Backward compatibility planlanmali

## 2026-03-06 - D-003 - Moduler Shell ve Import Standardi

- Durum: accepted
- Karar:
  - Plume, tek uzun `sh` dosyasi yerine `source` tabanli moduler shell mimarisi kullanacak
  - Ince entrypoint + `lib/` altinda command/engine/service modulleri olacak
- Gerekce:
  - Bakim ve gelistirme hizini artirmak
  - Faz bazli ayrismayi kod duzeyinde netlestirmek
  - AI/insan contributor icin degisiklik etkisini izlenebilir kilmak
- Etki:
  - Naming convention ve import disiplini zorunlu
  - Shellcheck ve temel script testleri release gate'e eklenmeli

## 2026-03-06 - D-004 - OS-Aware Core Prereq Fail-Fast Politikasi

- Durum: accepted
- Karar:
  - Plume, macOS/Linux ayrimini otomatik tespit edecek
  - Komut calismadan once profile gore core dependency kontrolu yapacak
  - Eksik zorunlu paket varsa komut calismayi durduracak ve kurulum yonergesi verecek
- Gerekce:
  - Yarim kurulum ve belirsiz hatalari azaltmak
  - Servis kurulumundan once altyapiyi deterministic hale getirmek
- Etki:
  - `prereq` komut ailesi ve profile mantigi zorunlu
  - OS/distro detection testleri release gate'e eklenmeli

## 2026-03-06 - D-005 - Merkezi Site Registry ve Interactive Onboarding

- Durum: accepted
- Karar:
  - Proje/site ekleme `plumectl site add` komutu ile prompt tabanli olacak
  - Registry, calisma dizininden bagimsiz merkezi konumda tutulacak
  - Kayitlar her zaman absolute path icerecek
  - Nginx/Apache2/Caddy adaptorleri ayni registry modelini kullanacak
- Gerekce:
  - Proje yollari ve komut calistirma konumu karmasasini bitirmek
  - Yeni proje ekleme adimini tek ve hizli bir akisa indirmek
- Etki:
  - `site` komut ailesi cekirdek parcaya donusur
  - Domain/path uniqueness ve drift kontrol mekanizmasi gerekir

## 2026-03-06 - D-006 - Dokumantasyon-First Gelistirme Kurali

- Durum: accepted
- Karar:
  - Her gelistirmede ilgili komut dokumani ve kontrat dosyalari ayni anda guncellenecek
  - Dokumansiz ozellik tamamlanmis sayilmayacak
- Gerekce:
  - Server tarafinda CLI'nin API-benzeri kullanimi icin net davranis gereksinimi
  - Gelecekteki `plume-adapter` projesinin hizli adaptasyonu
- Etki:
  - `docs/commands` ve `docs/contracts` release gate parcasidir

## 2026-03-06 - D-007 - 10 Fazli Gate-Driven Delivery

- Durum: accepted
- Karar:
  - Roadmap 10 faza bolunecek ve her faz test + dokumantasyon + karar kaydi olmadan kapanmayacak
- Gerekce:
  - Faz kapsamlarini kucultup riski dusurmek
  - Bir sonraki faza gecmeden kaliteyi garanti etmek
- Etki:
  - Faz gecislerinde resmi checklist zorunlu

## 2026-03-06 - D-008 - Mode Bazli Servis Destegi Gorunurlugu

- Durum: accepted
- Karar:
  - Native ve docker-lite desteklenen servis listesi hem ana dokumanda hem CLI komutu ile gosterilecek
  - Standart komut: `plumectl services supported [--mode=...]`
- Gerekce:
  - Operasyon sirasinda "bu modda ne destekli" sorusunu aninda cevaplamak
  - Adapter gelistirirken capability discovery'yi netlestirmek
- Etki:
  - Servis eklendikce matrix ve komut cikti sozlesmesi birlikte guncellenmeli

## 2026-03-06 - D-009 - Ops Constraints from Product Answers

- Durum: accepted
- Karar:
  - Privilege split: kurulum/guncelleme root, runtime komutlar non-root oncelikli
  - TLS/sertifika destegi zorunlu (docker-lite helper opsiyonlu)
  - DNS yonetimi simdilik scope disi, ileri faz backlog
  - Secret yonetimi ve rollback zorunlu
  - Firewall/OS security preflight zorunlu
  - Docker-lite native'e yuksek parity hedefler
  - Pinned version + optional auto-update desteklenir
  - JSON output sadece kritik komutlarda garanti edilir
  - Faz kapanisinda full E2E zorunlu
- Gerekce:
  - Operasyonel netlik ve production guvenilirligi
- Etki:
  - Faz 3/6/7/9/10 kapsamlarinda ek test ve dokuman zorunlulugu olusur

## 2026-03-06 - D-010 - Horizon icin Supervisor Zorunlulugu

- Durum: accepted
- Karar:
  - Laravel Horizon calistirilacaksa supervisor bagimliligi zorunlu kabul edilir
  - Native modda horizon operasyonlari supervisor uzerinden yonetilir
- Gerekce:
  - Horizon'un process yonetimi ve otomatik restart ihtiyaci
- Etki:
  - `services` ve `prereq` dokumanlarinda bagimlilik kurali zorunlu
  - Horizon E2E testleri supervisor var/yok senaryolari icermeli

## 2026-03-06 - D-011 - Service Custom Versions + PHP Alias Management

- Durum: accepted
- Karar:
  - Mariadb/Redis/PHP dahil servislerde custom version secimi desteklenecek
  - PHP icin multi-version yonetimi ve default `php` alias gecisi desteklenecek
  - Versioned aliaslar (`php81`, `php82`, `php83`) yönetilebilir olacak
- Gerekce:
  - Proje bazli runtime uyumlulugu ve gecis sureclerini kolaylastirmak
- Etki:
  - Config sozlesmesine version alanlari eklenir
  - `services` ve `php` komut ailelerinde version/alias islemleri zorunlu olur

## 2026-03-06 - D-012 - Plume Naming & CLI Collision Policy

- Durum: accepted
- Karar:
  - Product adi `Plume` olarak belirlenir
  - Official CLI binary `plumectl` olur
  - `plume` sadece opsiyonel alias olarak kullanilir
  - Repository adi `laravel-plume` standardize edilir
- Gerekce:
  - Linux ortamlarda olasi `plume` komut cakismalarini azaltmak
  - Marka adini korurken CLI ergonomisini guvende tutmak
- Etki:
  - Dokumantasyon ve komut ornekleri birincil olarak `plumectl` kullanir
  - Paket/formula adlari naming policy ile uyumlu secilir

## 2026-03-06 - D-013 - Herd Parity + Beyond ve Laravel Lifecycle Tamligi

- Durum: accepted
- Karar:
  - Plume, Laravel Herd parity hedefini local + production kapsayacak sekilde tasarlanir
  - Buna ek olarak deploy orchestration, rollback, secrets, security preflight ve advanced observability dahil edilir
  - Laravel proje lifecycle'i bootstrap -> runtime -> deploy -> operate -> recovery zinciriyle eksiksiz planlanir
- Gerekce:
  - "Laravel projesini sisteme en kolay ekleme" hedefini gercek operasyon kosullarinda tamamlamak
- Etki:
  - Faz gate checklist'i lifecycle ve parity checklist dogrulamasini zorunlu kilir
  - Runbook ve capability checklist belgeleri release kriterine dahil edilir

## 2026-03-06 - D-014 - Laravel Ecosystem Opsiyonel Servis Kapsami

- Durum: accepted
- Karar:
  - Mailpit, Meilisearch ve MinIO gibi Laravel ekosistem servisleri opsiyonel ama resmi kapsamda tutulur
  - Service support matrix ve config sozlesmesi bu servisleri mode bazli belirtir
- Gerekce:
  - Gercek dunya Laravel projelerinde mail/search/object storage ihtiyaclari sik gorulur
- Etki:
  - E2E senaryolarinda en az bir ekosistem servisi kombinasyonu test edilmelidir

## 2026-03-06 - D-015 - Minimal Default Services + Toggle-Aware Reconcile

- Durum: accepted
- Karar:
  - Varsayilan kurulumda yalnizca zorunlu set (`php`, `composer`, `mariadb`, `nginx`) aktif olur
  - Diger servisler default `false` olur
  - `services update` komutu configte `false -> true` gecen servisleri algilar, otomatik kurar ve baslatir
- Gerekce:
  - Ilk kurulumda hafiflik ve hiz
  - Sonradan ihtiyaca gore kontrollu genisleme
- Etki:
  - Config sozlesmesinde profile/toggle/reconcile alanlari zorunlu hale gelir
  - Reconcile davranisi icin E2E test senaryolari gerekir

## 2026-03-06 - D-016 - Unified .env Contract (Shared + Mode-Specific)

- Durum: accepted
- Karar:
  - Tum servis ve config degiskenleri `.env` uzerinden override edilebilir olacak
  - Repo kokunde `.env.example` dosyasi ortak degiskenleri ve mode-ozel degisken bloklarini icerecek
  - Prefix standardi: `PLUME_*`, mode-ozel: `PLUME_NATIVE_*`, `PLUME_DOCKER_LITE_*`, `PLUME_LARADOCK_*`
- Gerekce:
  - Local/prod ve mode gecislerinde tek tip konfigurasyon akisi saglamak
  - Adapter ve operasyon tarafinda degisken adlarini deterministic tutmak
- Etki:
  - Config loader katmani env precedence kurallarina gore calisir
  - Dokumantasyon ve ornek dosyalar release kriterine dahil edilir

## 2026-03-06 - D-017 - Phase 1 Closure Baseline

- Durum: accepted
- Karar:
  - Phase 1, foundation hedefiyle sinirli tutulur ve production-level orchestration bu fazda zorlanmaz.
  - `services install/up/down` komutlari Phase 1'de bilincli olarak hook/stub davranisinda birakilir.
  - Gercek service orchestration, versioning ve process management Phase 6 kapsaminda tamamlanir.
- Gerekce:
  - Fazlar arasi scope kaymasini engellemek
  - CLI ergonomisini erken test edilebilir kilarken teknik borcu kontrollu tasimak
- Etki:
  - Kullanici Phase 1'de komut akisini dogrulayabilir, ancak gercek servis kurulum beklentisi Phase 6'ya kayar
  - Dokumantasyon komutlari "phase1 stub" notuyla acikca belirtir

## 2026-03-06 - D-018 - Phase 2 Global Flag ve Router Baseline

- Durum: accepted
- Karar:
  - CLI router aileleri (`mode/services/prereq/site/project/deploy/backup/status`) tek dispatch tablosunda toplandi.
  - Global flag parser eklendi: `--help`, `--version`, `--json`, `--yes`, `--quiet`, `--env-file`.
  - JSON output Phase 2'de kritik komut alt-kumesi icin aktif edildi (`services supported`, `services status`, `prereq check`).
- Gerekce:
  - Komutlari adapter-readiness hedefiyle deterministic parse edilebilir hale getirmek
  - Sonraki fazlarda (prereq/site/orchestration) ayni flag ve cikti sozlesmesini tekrar kullanmak
- Etki:
  - Command ailesi placeholder'lari ile router stabil kalirken faz bazli implementation bagimsiz ilerler
  - `--env-file` ile test/prod farkli konfigurasyon dosyalarini kolay deneme imkani saglanir

## 2026-03-06 - D-019 - Phase 3 OS-Aware Prereq Guard + Linux Matrix

- Durum: accepted
- Karar:
  - `prereq check` profile bazli fail-fast modele gecirildi.
  - OS/package manager detection standardi netlesti: macOS=`brew`, Linux=`apt|dnf`.
  - Install/update aksiyonlarinda root boundary zorunlu hale getirildi.
  - macOS gelistirme ortami icin Linux dogrulamasi Docker matrix (Ubuntu + Fedora) ile standartlastirildi.
- Gerekce:
  - Host farkliliklarindan kaynaklanan belirsiz hatalari erken yakalamak
  - macOS uzerinde gelistirirken Linux davranisini dogrulayabilmek
- Etki:
  - `tests/phase3_prereq_smoke.sh` ve `tests/linux_prereq_matrix.sh` ile cross-OS smoke zinciri olustu
  - Phase 4+ komutlari prereq profillerini command-level baglamda tekrar kullanacak

## 2026-03-06 - D-020 - Phase 4 Site Command Baseline

- Durum: accepted
- Karar:
  - `site add/list/check/remove` komutları aktif hale getirildi ve `~/.config/plume/sites` registry modeli ile birlikte çalışacak şekilde bağlandı.
  - Etkileşimli olmayan koşullarda eksik `--path`/`--domain` girdilerinde komut fail-fast yapar.
  - Domain/path çakışmaları `force` hariç engellenir; publish işlemi başarısızsa kayıt rollback ile silinir.
- Gerekce:
  - Laravel projesini sisteme en az adımda ekleyebilen onboarding aksiyomunu oturtmak.
- Etki:
  - `site` komut ailesi Phase 4 fonksiyonel çıktısı olarak kabul edilir.
  - Dokümantasyon, faz planı ve parity notları eş zamanlı güncellenir.

## 2026-03-07 - D-021 - Postponed `plume.yml` Requirement

- Durum: accepted
- Karar:
  - `plume.yml` tabanlı site konfigürasyonu, test fazının zorunlu bir parçası olmayacak.
  - Testler ve mevcut phase-4 onboarding akışı merkezi registry odaklı kalacak.
  - `plume.yml` ve project-local Nginx davranışının uygulanması phase-4 sonrasına planlanacak.
- Gerekce:
  - Test odaklı fazlarda kapsam büyüklüğünü kontrol altında tutmak.
- Etki:
  - `implementation/phases/phase-04.md` ile `implementation/10-herd-parity-and-beyond.md` dosyalarında plan notu güncellendi.
  - Gelecek fazlarda migration path ve manifest lifecycle tasarımı bu karar doğrultusunda açılacak.

## 2026-03-07 - D-022 - Phase 5B Strict Mode + Dry-Run/Rollback Contract

- Durum: accepted
- Karar:
  - `site` komut ailesinde `--dry-run` eklenecek (`add/update/publish/remove`).
  - `site update --publish` adiminda publish basarisiz olursa record rollback uygulanacak.
  - `laradock-bridge` icin `PLUME_LARADOCK_STRICT=true` fail-fast preflight aktif olacak:
    - laradock path varligi
    - compose dosyasi varligi
    - hedef container varligi ve running durumu
  - Docker-lite compose preflight strict modu (`PLUME_DOCKER_LITE_COMPOSE_REQUIRED`) korunacak.
- Gerekce:
  - Mode parity'de guvenli operasyon icin dry-run ve rollback davranisinin deterministic olmasi.
  - Laradock entegrasyonunda belirsiz runtime hatalari yerine erken ve acik fail-fast davranisi.
- Etki:
  - Phase-05 kapsaminda strict/preflight ve rollback testleri zorunlu hale gelir.
  - Ops runbook ve env-contract dokumanlarina strict/dry-run kurallari eklenir.

## 2026-03-07 - D-023 - Phase 4 Closeout (Project Init + Manifest Baseline)

- Durum: accepted
- Karar:
  - `project` komut ailesi Phase-4 placeholder durumundan cikarildi, `project init` aktif edildi.
  - `project init` baseline adimlari netlesti: composer install, `.env` bootstrap, artisan key/storage adimlari, opsiyonel migrate/seed ve npm adimlari.
  - `plume.yml` phase-4 baseline sozlesmesi finalize edildi: project-local `mode` cozumlemesi + invalid mode fail-fast.
- Gerekce:
  - Phase-4'te Laravel projesini en az adimla sisteme alma hedefi `site` + `project init` birlikte tamamlanmis olur.
  - Faz kapatisinda test ve dokuman kanitlarinin gate kriterleriyle uyumlu olmasi gerekir.
- Etki:
  - Phase-4 checklist/gate maddeleri kapanir, tracker'da faz `done` durumuna gecer.
  - Geniş `plume.yml` schema (service/site detaylari) sonraki fazlara tasinan kontrollu bir backlog olarak korunur.

## 2026-03-07 - D-024 - Phase 6 Native Service Runtime Contract

- Durum: accepted
- Karar:
  - Native mode icin service runtime sozlesmesi dosya-tabanli hale getirildi:
    - runtime state: `services_runtime_native.env`
    - allocated ports: `services_ports_native.env`
    - logs: `~/.config/plume/logs/services/native/<service>.log`
  - `services status` ciktilarina `running`, `health`, `port` alanlari eklendi.
  - `services health` ve `services logs` komutlari eklendi.
  - Port kullanan servislerde default port doluysa `+1..+50` fallback araligi uygulanacak.
- Gerekce:
  - Native orchestration fazinda deterministic lifecycle gozlemi ve debug edilebilirlik gerekir.
  - Full systemd entegrasyonundan once, test edilebilir bir runtime abstraction katmani gerekir.
- Etki:
  - Phase-6 implementation/test/docs gate maddeleri kapanir.
  - Phase-7/8'de docker-lite ve laradock runtime sozlesmeleri bu kontrata hizalanir.

## 2026-03-07 - D-025 - Phase 7 Docker-Lite Runtime Parity

- Durum: accepted
- Karar:
  - Docker-lite service adaptorlari compose tabanli lifecycle ile tamamlandi (`pull/up/stop`).
  - `services workspace up|down|status --mode=docker-lite` komutu eklendi.
  - Docker-lite icin `health` ve `logs` akislari compose `ps/logs` entegrasyonu ile baglandi.
  - Compose strict-mode davranisi korundu: `PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true` ise compose zorunlu fail-fast; degilse stub fallback devam eder.
- Gerekce:
  - Native ile docker-lite arasinda ayni komut yuzeyiyle operasyonel parity saglamak.
  - Docker bulunmayan/dev ortamlarinda geriye donuk uyumlulugu bozmadan ilerlemek.
- Etki:
  - Phase-7 checklist/gate kapanir.
  - Phase-8 laradock bridge runtime contract'i icin referans davranis tanimlanmis olur.

## 2026-03-08 - D-026 - Docker-Lite Template Baseline + Image Suggestion Preflight

- Durum: accepted
- Karar:
  - `templates/docker-lite/docker-compose.template.yml` eklendi.
  - Laradock-esintili hafif modelde `workspace`, `nginx|apache2|caddy` ve `php81|php82|php83|php84-fpm` clone servisleri template'e dahil edildi.
  - `services workspace up --mode=docker-lite` image preflight'i image yoksa benzer image onerisi basacak sekilde genisletildi.
- Gerekce:
  - Kullanicilarin dogrudan baslayabilecegi, ozellestirilebilir bir docker-lite baseline sunmak.
  - Broken image/tag durumunda ara surecte belirsiz docker hatasi yerine erken ve yol gosterici hata almak.
- Etki:
  - Docker-lite onboarding hizlanir; compose ve service mapping sozlesmesi daha acik hale gelir.
  - Phase-8 laradock-bridge template/sync kararlarina giris zemini olusur.

## 2026-03-08 - D-027 - Docker-Lite Workspace Stub Generator + Dynamic Default PHP

- Durum: accepted
- Karar:
  - `services workspace init --mode=docker-lite --path=<dir>` komutu eklendi.
  - Komut hedef dizinde docker-lite stub olusturur:
    - `docker-compose.yml`
    - `docker-lite/{nginx,apache2,caddy}` config dosyalari
    - `.env.docker-lite`
  - Default PHP runtime `php-fpm` servisi dinamik hale getirildi:
    - `PLUME_DOCKER_LITE_PHP_DEFAULT_VERSION`
    - `PLUME_DOCKER_LITE_PHP_FPM_IMAGE`
  - Clone modeller (`php81-fpm`, `php82-fpm`, `php83-fpm`, `php84-fpm`) template icinde korundu.
- Gerekce:
  - Kullaniciya "istenen dizinde tek komutla calisan docker-lite baseline" sunmak.
  - PHP default surum degiskeni ile runtime secimini sabit config degisimi olmadan yapabilmek.
- Etki:
  - `.env`/template senkronizasyonu guclendi.
  - Docker-lite kontrol akisi plume komutlariyla hizli ve tekrar edilebilir hale geldi.

## 2026-03-08 - D-028 - Docker-Lite Port Policy Alignment with Native

- Durum: accepted
- Karar:
  - Docker-lite service start akisinda native benzeri port allocation/fallback aktif edildi.
  - Varsayilan web davranisi tek aktif web server + host port `80` olarak sabitlendi.
  - `nginx/apache2/caddy` icin ayrik 808x varsayimlari kaldirildi; tumu `PLUME_WEB_PORT` (default 80) tabanina cekildi.
- Gerekce:
  - Native ve docker-lite modlari arasinda port yonetimi davranis paritesi.
  - Varsayilan kullanimda gereksiz port dagilimini ve kafa karisikligini azaltmak.
- Etki:
  - Docker-lite status/state ciktilari port fallback sonuclarini gostermeye baslar.
  - Orchestrasyonda tek-webserver varsayimi netlesir; coklu web server kullanimi explicit profile secimine birakilir.

## Template

- `YYYY-MM-DD - D-XXX - Baslik`
- Durum: proposed | accepted | deprecated
- Karar:
- Gerekce:
- Etki:

## 2026-03-10 - D-029 - Docker-Lite Beta Freeze ve Phase-08 Oncelik Degisimi

- Durum: accepted
- Karar:
  - Docker-lite fazi `beta-frozen` durumuna alindi; kalan lightweight/local+production ergonomi isleri backlog'a tasindi.
  - Aktif gelistirme odagi Phase-08'e kaydirildi: `laradock-bridge` adaptorlerinin native komut yuzeyiyle parity saglamasi.
  - Native + laradock-bridge davranis birligi, kisa vadede ana teslim kriteri olarak belirlendi.
- Gerekce:
  - Docker-lite hedeflenen "tek cati hafif local/prod" deneyimine henuz ulasmadi; bu noktada ilerlemek yerine mevcut calisan Laradock ekosisteminde hizli deger uretmek daha verimli.
  - Laradock uzerinde zaten calisan servis topolojisini plume komutlariyla yonetmek, kullanici degeri ve adoption riskini azaltir.
- Etki:
  - Phase-07 kapanis statusu `done` yerine `beta-frozen` olarak revize edildi.
  - Phase-08 `in-progress` statuye cekildi ve test/dokuman onceligi laradock-bridge + native parity olarak guncellendi.
  - Docker-lite degisiklikleri regressionsiz korunacak, yeni major is kapsam disi kalacak.

## 2026-03-10 - D-030 - Laradock Bridge Bootstrap Komutlari (init/sync/check)

- Durum: accepted
- Karar:
  - `services laradock init|sync|check --mode=laradock-bridge` komut ailesi eklendi.
  - `init` varsayilan Laradock repo (`https://github.com/laradock/laradock.git`) ile clone/pull yapar, `--repo` ile custom origin destekler.
  - `sync` branch/repo bazli git fetch/pull akisini standardize eder.
  - `check` strict guard uygular:
    - required service list compose'ta mevcut mu
    - `.env` icinde `APP_CODE_PATH_CONTAINER=/var/www` mi
    - `APP_CODE_PATH_HOST` cozumlenebilir mi
    - laradock-bridge mode site path'leri host scope disina cikiyor mu
- Gerekce:
  - Laradock uzerinde calisan mevcut sistemlere hizli ve guvenli entegrasyon gereksinimi.
  - Native ile ayni komut yuzeyini bridge modda fail-fast preflight ile guvenceye almak.
- Etki:
  - Phase-08 implementation checklist'inde discovery + compatibility guard maddeleri aktif/ilerlemis hale geldi.
  - `mode path set/get laradock-bridge` akisi, laradock bootstrap komutlariyla dogrudan kullanim kazandi.

## 2026-03-24 - D-031 - Readiness Baseline Clarification for Native and Laradock-Bridge

- Durum: accepted
- Karar:
  - 2026-03-24 itibariyla mod bazli gercek readiness durumu resmi olarak netlestirildi ve ayri durum notuna kaydedildi:
    - `implementation/11-status-2026-03-24.md`
  - `docker-lite` aktif gelistirme disinda kalmaya devam eder.
  - `native` icin mevcut durum "command surface + stateful orchestration" olarak kabul edilir; tam host provisioning olarak degil.
  - `laradock-bridge` icin mevcut durum "bootstrap + strict preflight" olarak kabul edilir; tam runtime lifecycle parity olarak degil.
- Gerekce:
  - Sonraki thread'lerde veya contributor degisimlerinde mevcut kabiliyetler fazla varsayilmasin.
  - Native ve laradock-bridge icin bir sonraki implementasyon adimlari net teknik gerceklik uzerinden ilerlesin.
- Etki:
  - Bundan sonraki Phase-08 ve native parity isleri bu readiness baseline'a gore planlanacak.
  - `workspace`, `phpmyadmin`, `redis-webui`, `php-worker`, `horizon` gibi hedefler icin "surface var / gercek runtime yok" ayrimi korunacak.

## 2026-03-24 - D-032 - Laradock Runtime Context Must Be Explicit + Live Compose Wins

- Durum: accepted
- Karar:
  - `laradock-bridge` runtime komutlari (`services status|health|logs|up|down|exec|containers`) yalnizca explicit Laradock context ile calisir.
  - Laradock path onceligi:
    - `--path`
    - `mode path set laradock-bridge ...`
  - Runtime path tahmin edilmez; path ayarsizsa komut fail-fast olur.
  - Laradock runtime source-of-truth canli `docker compose` durumudur; state env dosyalari ve SQLite yalnizca cache/telemetry katmanidir.
- Gerekce:
  - Yanlis Laradock dizinine dokunma riskini kaldirmak.
  - Bridge modda gercek container durumunu esas alip state drift'ini azaltmak.
- Etki:
  - `services` komutlari Laradock path validation olmadan calismaz.
  - Phase-08A implementasyonu status/health/logs/up/down komutlarini live compose tabanina tasir.

## 2026-03-24 - D-033 - Laradock Bridge State Sync Uses Live Compose as Cache Source

- Durum: accepted
- Karar:
  - `sync state --mode=laradock-bridge` komutu eklendi.
  - `services status --mode=laradock-bridge` cagrisi oncesinde live compose -> state reconcile tetiklenir.
  - Reconcile akisi:
    - running state
    - live port metadata
    - `services_runtime_laradock-bridge.env`
    - `services_ports_laradock-bridge.env`
    - `plume-state.db`
- Gerekce:
  - Kullanici docker tarafinda plume disinda islem yapsa bile state drift'ini azaltmak.
  - Status ekraninin stale cache yerine canli runtime'a dayanmasini saglamak.
- Etki:
  - Laradock bridge status ciktilari SQLite/cache ile daha tutarli hale gelir.
  - Phase-08'de bridge sync/state mapping maddesi tamamlanmis sayilir.

## 2026-03-25 - D-034 - Mode-Isolated Service Enabled Semantics

- Durum: accepted
- Karar:
  - `enabled` alani tum modlarda ayni kaynaktan hesaplanmaz.
  - `native` ve `docker-lite` icin `enabled` = Plume env toggle/config.
  - `laradock-bridge` icin `enabled` = ilgili service Laradock compose icinde var mi.
  - Laradock'ta `nginx/apache2/caddy` health/status hesaplari birbirinden ayrik compose service uzerinden okunur.
- Gerekce:
  - Laradock mevcut stack'ini env toggle mantigina zorla indirgemek yanlis gorunum ve modlar arasi karisikliga yol aciyordu.
  - Her mode'un servis yonetimi semantigi kendi engine gercekligine dayanmalidir.
- Etki:
  - `services status` ciktilari mod bazli daha dogru ve daha acik hale gelir.
  - Kullanici Laradock modunda compose'da var olan servisleri net gorur; native/docker-lite state ile karismaz.

## 2026-03-25 - D-035 - Laradock Runtime Uses Full Compose Service Discovery

- Durum: accepted
- Karar:
  - `laradock-bridge` modunda service listesi static Plume baseline ile sinirli kalmaz.
  - `services supported`, `services status`, `services up all`, `services down all` komutlari aktif Laradock `docker-compose.yml` icindeki tum servisleri compose'dan discover eder.
  - Plume alias'lari korunur:
    - `php` -> `php-fpm`
    - `composer` -> `workspace`
    - `horizon|supervisor` -> `laravel-horizon`
- Gerekce:
  - Kullanici Laradock altindaki tum servisleri gormek ve yonetmek istiyor; static support listesi bunun icin yetersiz.
  - Bridge mode'un amaci mevcut Laradock stack'i oldugu gibi adapte etmektir.
- Etki:
  - Laradock status/supported ciktisi compose gercegine dayanir.
  - Sync/runtime state dosyalari Laradock'ta raw compose service adlariyla tutulmaya baslar.

## 2026-03-25 - D-036 - Laradock `all` Lifecycle Uses Desired Service Set

- Durum: accepted
- Karar:
  - Laradock'ta `services up all` ve `services down all` komutlari artik compose icindeki tum servisleri hedeflemez.
  - Hedef servis seti SQLite `desired_services` tablosunda tutulur.
  - Yeni komut ailesi:
    - `services config show --mode=laradock-bridge`
    - `services config add <service|@group> --mode=laradock-bridge`
    - `services config remove <service|@group> --mode=laradock-bridge`
    - `services config reset --mode=laradock-bridge`
  - Group hedefleri (`@core`, `@web`, `@db`, `@queue`) desired sete yazilabilir.
- Gerekce:
  - Kullanici Laradock'taki tum servisleri degil, proje icin gercekten istedigi servis setini yonetmek istiyor.
  - `all` davranisinin compose'taki her seyi etkilemesi production/local parity acisindan fazla genis ve riskli.
  - SQLite tabanli desired set, duz dosyaya gore daha guvenilir ve sorgulanabilir.
- Etki:
  - Laradock lifecycle daha kontrollu hale gelir.
  - `services status/supported` compose gercegini gostermeye devam eder; `up/down all` ise desired config gercegine gore calisir.

## 2026-04-03 - D-037 - Laradock `up all` Safe Ordering + Rollback

- Durum: accepted
- Karar:
  - `services up all --mode=laradock-bridge` resolved service setini safe-order ile calistirir:
    - `db -> php -> queue -> web -> others`
  - `services down all --mode=laradock-bridge` ters safe-order ile calisir:
    - `web -> queue -> php -> db -> others`
  - `up all` sirasinda bir servis start fail ederse, ayni komutta daha once baslatilan servisler ters sirada rollback stop edilir.
- Gerekce:
  - Mevcut Laradock stack'lerinde rastgele start/stop sirasi race condition ve bagimlilik hatasi riski uretiyordu.
  - Basarisiz kismi kalkis sonrasi yari-aktif sistem birakmamak gerekiyor.
- Etki:
  - `laradock-bridge` lifecycle davranisi daha deterministic hale geldi.
  - Failure rollback ile kismi start durumlarinda manuel cleanup ihtiyaci azalir.

## 2026-04-03 - D-038 - Adapter Contract Normalization Across Modes

- Durum: accepted
- Karar:
  - `services` komut ailesinde mode'dan bagimsiz aliaslar normalize edilir:
    - `php-fpm -> php`
    - `workspace -> composer`
    - `php-worker -> php_worker`
    - `laravel-horizon -> horizon`
  - Bu normalizasyon `service exists`, target resolve, version validate ve callback invoke zincirinde uygulanir.
- Gerekce:
  - Kullanici komut yuzeyinde mode dusunmeden ayni servis adlariyla calisabilmeli.
  - Native ve laradock-bridge arasinda ayni command surface hedefi icin isim kontrati deterministik olmali.
- Etki:
  - Alias kaynakli "unknown service" hatalari azalir.
  - Phase-08 icindeki `native<->laradock-bridge adapter contract normalization` maddesi kapanir.

## 2026-04-03 - D-039 - Bridge Port/State Introspection Uses Multi-Port Snapshot

- Durum: accepted
- Karar:
  - `sync state --mode=laradock-bridge` artik tek host port degil, container'da publish edilen tum host portlarini state'e yazar.
  - Web servisleri (`nginx/apache2/caddy/openresty`) icin `web_https` key'i de 443 map'inden senkronize edilir.
- Gerekce:
  - Laradock stack'lerinde `workspace` ve benzeri servisler birden fazla port publish eder.
  - Tek-port snapshot operasyonel gorunurlugu eksik birakiyordu.
- Etki:
  - `services_ports_laradock-bridge.env` ve state DB daha dogru runtime port gorunumu tasir.
  - Phase-08 `port/state introspection` maddesi kapanir.

## 2026-04-03 - D-040 - Safe Interop Defaults + Cross-Mode Command Surface Equivalence

- Durum: accepted
- Karar:
  - `laradock-bridge` modunda `up/down all` davranisi non-destructive default kalir:
    - yalnızca desired/resolved set hedeflenir
    - desired disi compose servisleri etkilenmez
  - Adapter contract aliaslari native ve laradock-bridge modunda ayni sekilde calisir:
    - `php-fpm`, `workspace`, `php-worker`, `laravel-horizon`
- Gerekce:
  - Mevcut Laradock stack'lerde plume disi servisleri istemeden etkilemek kritik risktir.
  - Mod degistiginde komut adlarinin degismesi operasyonel hata olasiligini artirir.
- Etki:
  - Phase-08 scope checklist'teki
    - `Safe interoperability and no destructive defaults`
    - `Native ile komut-esdegerligi`
    maddeleri kapanir.

## 2026-04-03 - D-041 - Phase 09 Start: Observability-First Ops Baseline

- Durum: accepted
- Karar:
  - Phase-09 `in-progress` olarak baslatildi.
  - Ilk teslim dilimi `doctor/monitor` temel kontratina odaklanir:
    - `doctor check`
    - `doctor services`
    - `doctor ports`
  - `status/health/logs --watch` ciktilari production-ops icin telemetry katmani olarak kullanilir.
  - Critical failure durumlarinda fail-fast + audit event kaydi zorunlu olur.
- Gerekce:
  - Phase-08 ile runtime parity tamamlandi; production operasyonu icin gorunurluk ve risk surfacing bir sonraki kritik katmandir.
- Etki:
  - Phase-09 backlog'u monitorability, security checks, cert/secrets ve recovery runbook ekseninde ilerler.

## 2026-04-03 - D-042 - Doctor Baseline Routed and Test-Gated

- Durum: accepted
- Karar:
  - `doctor` komut ailesi CLI ana router'a baglandi ve help ciktisina eklendi.
  - Alt komut kontrati netlestirildi:
    - `doctor check [--mode=...] [--deep]`
    - `doctor services [--mode=...]`
    - `doctor ports [--mode=...]`
  - Baseline davranislar `tests/phase9_doctor_smoke.sh` ile test-gate altina alindi.
- Gerekce:
  - Phase-09 observability katmanina giriste command surface'in kullaniciya gorunur ve testlenebilir sekilde sabitlenmesi gerekir.
  - Router'a bagli olmayan komutlar dokumantasyonla uyumsuzluk ve regressions riski uretir.
- Etki:
  - `doctor` komutlari artik standart komut akisinda erisilebilir.
  - Phase-09 ilk dilimde hizli dogrulama icin minimum smoke kapsami olustu.

## 2026-04-03 - D-043 - Ops Wrapper Commands + Runtime Audit Events

- Durum: accepted
- Karar:
  - `status`, `health`, `logs` top-level komutlari aktif edildi ve ilgili `services` komutlarina wrapper olarak baglandi.
  - Yeni `monitor` komut ailesi eklendi:
    - `monitor summary`
    - `monitor watch`
    - `monitor events`
  - Bu komutlar icin state DB `runtime_events` tablosuna `ops.*` prefixli audit event kaydi zorunlu hale getirildi.
- Gerekce:
  - Phase-09 operasyonel gorunurluk hedefi icin tek-komutlu izleme akisina ve komut-audit izine ihtiyac var.
  - `services` alt komutlarini bilen/bilmeyen kullanicilar icin ust seviye komut yuzeyi sade kalmali.
- Etki:
  - Observability komut ailesi dogrudan kullanilabilir hale geldi.
  - `monitor events` ile son operasyonlarin izlenebilirligi state DB uzerinden saglandi.

## 2026-04-03 - D-044 - Monitor Summary Failure Scoring + Strict Exit

- Durum: accepted
- Karar:
  - `monitor summary` icin servis tarama tabanli skor modeli eklendi:
    - `OVERALL=OK|WARN|FAIL`
    - `CRITICAL`, `WARN`, `RUNNING`, `HEALTHY` sayaçları
    - issue listesi (`service: running=..., health=...`)
  - `--strict` verildiginde `CRITICAL>0` ise komut exit code `2` doner.
- Gerekce:
  - Kritik sorunlarin yalnız tablo satirlarinda kalmasi yerine tek satir overall sinyali gerekir.
  - CI/ops otomasyonlari icin kritik durumlarda deterministik non-zero exit zorunludur.
- Etki:
  - `monitor summary` hem insanlar icin okunabilir, hem otomasyon icin aksiyon alinabilir hale geldi.

## 2026-04-03 - D-045 - Critical Command Guard Policy (`--yes`) + Audit Trail

- Durum: accepted
- Karar:
  - Asagidaki kritik komutlar icin explicit `--yes` onayi zorunlu:
    - `mode use --force`
    - `mode path set|clear --force`
    - `services workspace reinit`
    - `services update`
  - Guard sonucu her cagrida `runtime_events` tablosuna audit edilir:
    - `critical.<operation>.blocked`
    - `critical.<operation>.approved`
- Gerekce:
  - Yanlislikla context/path degistirme veya workspace reset gibi islemler yuksek etki yaratir.
  - Audit izi olmadan production benzeri ortamlarda geri izleme ve olay analizi zorlasir.
- Etki:
  - Kritik komutlarin accidental execution riski azalir.
  - Denetlenebilir, tutarli bir approval trail olusur.

## 2026-04-03 - D-046 - Recovery Runbook Command Surface (`monitor runbook`)

- Durum: accepted
- Karar:
  - `monitor runbook` alt komutu eklendi ve komut-odakli recovery akislari standardize edildi.
  - Desteklenen senaryolar:
    - `incident`
    - `recovery`
    - `ports-conflict`
  - Operasyon dokumani `docs/operations/incident-triage-runbook.md` ile komut zinciri eslestirildi.
- Gerekce:
  - Olay aninda rastgele komut secimi yerine deterministik bir adim listesi gerekir.
  - “runbooks wired to commands” hedefi icin dokuman + CLI cikti kontrati birlikte olmalidir.
- Etki:
  - Recovery akislarina tek komutla erisim saglandi.
  - Incident triage dokumani CLI ile dogrudan uyumlu hale geldi.

## 2026-04-03 - D-047 - Backup Baseline (`backup create/list/show/restore`) + Guarded Restore

- Durum: accepted
- Karar:
  - `backup` komut ailesi aktive edildi:
    - `backup create`
    - `backup list`
    - `backup show`
    - `backup restore`
  - Restore islemi kritik kabul edilerek `--yes` guard altina alindi (`--dry-run` haric).
  - Backup/restore ve guard olaylari runtime audit'e yazilir:
    - `backup.create.ok`
    - `backup.restore.ok`
    - `critical.backup.restore.(blocked|approved)`
- Gerekce:
  - Phase-09 hedefindeki operasyonel geri donus kabiliyeti icin minimum restoreable baseline gerekir.
  - Yanlis restore cagrilarinin onlenmesi ve olay kaydi production hijyeni icin zorunludur.
- Etki:
  - Konfig/state geri yukleme akisi CLI seviyesinde kullanilabilir hale geldi.
  - Security+backup dokuman seti komut davranisiyla hizalandi.

## 2026-04-03 - D-048 - Rollback/Failback Baseline via `deploy` + Backup Integration

- Durum: accepted
- Karar:
  - `deploy` komut ailesinde baseline rollback mekanizmasi aktive edildi:
    - `deploy plan`
    - `deploy rollback <id|latest>`
    - `deploy failback`
  - `deploy rollback` cagrisi restore oncesi otomatik failback noktasi olusturur.
  - `deploy failback` en son failback noktasini geri yukler.
  - Rollback/failback kritik komut guard altina alindi (`--yes`, dry-run haric).
- Gerekce:
  - Production benzeri akislar icin tek komutla geri donus mekanizmasi gerekir.
  - Rollback sonrasi beklenmeyen durumda bir adim geri donmek icin failback noktasi zorunludur.
- Etki:
  - Phase-09 rollback/failback hedefi komut seviyesinde kullanilabilir hale geldi.
  - Audit trail, deploy geri donus olaylarini kapsar (`deploy.*`, `critical.deploy.*`).

## 2026-04-03 - D-049 - Security Baseline Command Surface (`security check` + `security secrets`)

- Durum: accepted
- Karar:
  - Yeni `security` komut ailesi eklendi:
    - `security check` (OS/firewall preflight snapshot)
    - `security secrets list|get|set|unset|generate`
  - Secret store state dizininde `secrets.env` uzerinde yonetilir (mode-agnostic, local baseline).
  - Security/secrets operasyonlari runtime audit'e yazilir (`security.*`).
- Gerekce:
  - Phase-09 kapsamindaki secret management ve OS security checks maddeleri icin minimum CLI baseline gerekir.
  - Tekrarlanabilir ve izlenebilir bir secret operasyon yuzeyi olmadan adapter/sunucu katmani guvenli ilerleyemez.
- Etki:
  - Secret management baseline ve firewall preflight komut seviyesinde tamamlandi.
  - Operasyon ekipleri icin `doctor/monitor` disinda guvenlik odakli komut seti olustu.

## 2026-04-03 - D-050 - Project `.env` Secret Sync Bridge (`project env sync-secrets`)

- Durum: accepted
- Karar:
  - `project env sync-secrets` alt komutu eklendi.
  - Kaynak: `$(plume_state_dir)/secrets.env`
  - Hedef: `<project>/.env`
  - Desteklenen davranislar:
    - secili key sync (`--keys=K1,K2`)
    - tum keyleri sync (keys verilmezse)
    - dry-run
    - `.env` yoksa `--create-env` ile `.env.example` uzerinden olusturma
  - Operasyon runtime event'e kaydedilir: `project.env.sync-secrets.ok`.
- Gerekce:
  - Secret baseline'in pratik degeri, Laravel proje `.env` dosyasina guvenli/tekrarlanabilir aktarimla ortaya cikar.
  - Manuel kopyalama hatalarini azaltmak ve repeatable provisioning akisina gecmek gerekir.
- Etki:
  - `security secrets` ile saklanan keyler proje onboarding/deploy oncesi tek komutla senkronize edilebilir.

## 2026-04-03 - D-051 - TLS Baseline with Multi-Domain Local Cert Flow (`security cert`)

- Durum: accepted
- Karar:
  - `security cert` alt komutlari eklendi:
    - `issue --domains=d1,d2 [--days=30] [--name=id]`
    - `list`
    - `show <id>`
    - `renew <id> [--days=30]`
  - Sertifika artifactleri state altina yazilir: `$(plume_state_dir)/certs/<id>/`.
  - Çoklu domain SAN (`subjectAltName`) bilgisi cert issue/renew akislariyla korunur.
  - Olaylar runtime audit'e yazilir (`security.cert.*`).
- Gerekce:
  - Phase-09 TLS/certificate hedefi icin en dusuk bagimlilikla (openssl) tekrar edilebilir local baseline gerekir.
  - Multi-domain cert gereksinimi (site/domain parity) SAN tabanli cert uretimini zorunlu kilar.
- Etki:
  - Cert issue/renew lifecycle'i CLI seviyesinde testlenebilir ve izlenebilir hale geldi.

## 2026-04-03 - D-052 - Site-Level TLS Binding (`site --cert-id`) and HTTPS Snippet Rendering

- Durum: accepted
- Karar:
  - `site add|update` komutlarina `--cert-id` ve `--https-port` alanlari eklendi.
  - `cert_id` set edildiginde site publish render davranisi HTTPS odakli olur:
    - nginx: HTTP->HTTPS redirect + `listen <https_port> ssl` + cert/key
    - apache2: HTTP vhost redirect + SSL VirtualHost + cert/key
    - caddy: `tls <crt> <key>`
  - Publish oncesi cert artifact varligi dogrulanir.
- Gerekce:
  - Cert üretiminin operasyonel degeri ancak site-level binding ile ortaya cikar.
  - Mode parity hedefi icin web server adapterlerinde tutarli TLS render gerekir.
- Etki:
  - `security cert` ile uretilen certler dogrudan site lifecycle komutlariyla kullanilabilir.
  - Site check/list ciktisinda `cert_id` ve `https_port` gorunurlugu saglandi.

## 2026-04-03 - D-053 - Phase 09 Closure: Ops/Security/Recovery Baseline Completed

- Durum: accepted
- Karar:
  - Phase-09 gate maddeleri tamamlandi ve faz `done` olarak kapatildi.
  - Kapsam tamamlandi: observability suite, TLS baseline, secrets baseline, rollback/failback, backup scope, security/firewall checks.
- Gerekce:
  - Faz hedeflerindeki komut/dokuman/test uclusu tamamlandi ve smoke zinciri stabil calisiyor.
- Etki:
  - Phase-10 icin stabilizasyon ve adapter-hazirlik odakli net bir baslangic noktasi olustu.

## 2026-04-03 - D-054 - Phase 10 Kickoff with Single-Command E2E Matrix Baseline

- Durum: accepted
- Karar:
  - Phase-10 `in-progress` olarak baslatildi.
  - `tests/phase10_e2e_matrix_smoke.sh` eklendi; native + laradock-bridge baseline + docker-lite beta-frozen regression kontrolu tek komuta toplandi.
  - Release oncesi operasyonel no-go kriterleri `docs/operations/release-readiness.md` ile standardize edildi.
  - CLI output contract dokumani phase-10 text-table stabilizasyon kurallariyla genisletildi.
- Gerekce:
  - Faz-10 hedefi olan stabilization/release readiness icin dağınık smoke komutlarini tek bir entrypoint'e toplamak gerekir.
  - Adapter tarafi parse kirilmalarini azaltmak icin text/json output kurallari acik olmalidir.
- Etki:
  - Release quality gate daha tutarli ve tekrar edilebilir hale geldi.
  - Plume-adapter onboarding oncesi parse kontrati netlesti.

## 2026-04-03 - D-055 - Phase 10 Closure: Stabilization + Release + Adapter Baseline Completed

- Durum: accepted
- Karar:
  - Phase-10 checklist maddeleri kapatildi ve faz `done` durumuna alindi.
  - E2E matrix zinciri, rollback regression ve install-to-operate journey testleri release zincirine eklendi.
  - Release versioning/tag policy ve adapter onboarding dokumani kalici hale getirildi.
- Gerekce:
  - Plume'in mevcut scope'u icin release-ready baseline ve adapter-entegrasyon baglami artik dokuman+test+karar ucgeninde tutarli.
- Etki:
  - Fazli roadmap ilk dongusu tamamlandi; sonraki adimlar (golden contract snapshots, CI matrix) net sekilde backlog'a ayrildi.

## 2026-04-03 - D-056 - Phase 11 Kickoff: Native Adapter Contract Parity

- Durum: accepted
- Karar:
  - Yeni faz acildi: `Phase 11 - Native Adapter Contract Parity`.
  - Oncelik, native modda laradock-benzeri tek contract deneyimi:
    - service alias/semantic parity
    - site+php runtime parity
    - horizon/supervisor lifecycle parity
    - mariadb/mysql/redis/phpmyadmin operational parity
- Gerekce:
  - Kullanici beklentisi mode-agnostic tek komut deneyimi; native modun docker/laradock kadar tutarli hissettirmesi gerekiyor.
- Etki:
  - Gelistirme odağı docker-lite’tan (beta-frozen) native adapter contract derinlestirmesine kaydirildi.

## 2026-04-03 - D-057 - Native Alias Contract Regression Baseline (Phase-11 Slice-1)

- Durum: accepted
- Karar:
  - Native mode icin adapter-alias davranisi regression testiyle kilitlendi:
    - `php-fpm -> php`
    - `workspace -> composer`
    - `laravel-horizon` cagrilarinda supervisor dependency guard
  - Yeni test: `tests/phase11_native_adapter_contract_smoke.sh`
- Gerekce:
  - "Mode-agnostic tek komut deneyimi" hedefinde ilk kirilma noktasi alias semantigi; bunu erken kilitlemek sonraki parity islerini guvenli hale getirir.
- Etki:
  - Phase-11 sonraki dilimlerinde yapılacak profile/site/php/db parity degisiklikleri icin guvenli baseline olustu.

## 2026-04-03 - D-058 - Core Service Parity Lock (Phase-11 Scope Freeze)

- Durum: accepted
- Karar:
  - Phase-11 icin once su cekirdek servislerde birebir parity kilitlendi:
    - `php(fpm)`
    - `nginx/caddy/apache2`
    - `mariadb/mysql`
    - `phpmyadmin`
    - `laravel-horizon` (+ supervisor dependency)
    - `redis`
  - Bu kapsam icin yeni smoke testi eklendi:
    - `tests/phase11_native_core_services_parity_smoke.sh`
- Gerekce:
  - Kullanici onceligi bu servislerde mode-agnostic adapter davranisinin birebir olmasi.
  - Diger servisler bu cekirdek set tamamlanmadan roadmap'e alinmayacak.
- Etki:
  - Phase-11 gelisim sirasi netlesti; kapsamin dagilmasi engellendi.

## 2026-04-03 - D-059 - Native PHP Matrix Structure (Default + Custom Versions)

- Durum: accepted
- Karar:
  - Gercek `php` komut ailesi eklendi:
    - `php list`
    - `php install <version>`
    - `php use <version|alias>`
    - `php alias list|set|default`
  - Native PHP matrix konfigurasyonu kalici state dosyasina yazilir:
    - `~/.config/plume/state/php.env` (veya `PLUME_STATE_DIR/php.env`)
  - `php install` canonical alias auto-create eder (`8.4 -> php84`).
  - `php use` secilen surumu default yapar ve gerekirse installed listeye ekler.
- Gerekce:
  - Native modda ana/default PHP ve ek custom PHP surumlerini kalici ve adapter-dostu sekilde yonetmek isteniyor.
  - Bu olmadan `services up php --version=<alias|version>` davranisi tekrarlanabilir degildi.
- Etki:
  - Native mode php surum secimi artik komut-seviyesinde yonetilebilir ve kalici.
  - Phase-11 parity akisinda site/php runtime contract hardening icin temel zemin olustu.

## 2026-04-03 - D-060 - Safe Mode Switch from Laradock-Bridge to Native (`--down-running`)

- Durum: accepted
- Karar:
  - `mode use` komutuna `--down-running` secenegi eklendi.
  - Mevcut mod `laradock-bridge` ve containerlar calisiyorsa:
    - `--down-running` yoksa gecis bloklanir ve net yonlendirme mesaji verilir.
    - `--down-running` varsa plume, ilgili compose context'te `docker compose down` calistirip sonra mode switch yapar.
- Gerekce:
  - Native moda geciste port cakismasi ve yarim-kalan runtime state riskini azaltmak gerekiyor.
- Etki:
  - Kullaniciya kontrollu ve deterministic bir gecis yolu sunuldu.
  - Phase-11 parity akislari icin mode gecis guvenligi guclendi.

## 2026-04-03 - D-061 - Global Native Env Model (System-Level `.env`)

- Durum: accepted
- Karar:
  - Varsayilan env kaynagi proje-yerel `.env` yerine global plume env oldu:
    - `~/.config/plume/.env` (override: `PLUME_GLOBAL_ENV_FILE`)
  - Global env yoksa bootstrap:
    - once `~/.config/plume/.env.example`
    - yoksa calisma dizinindeki `.env.example`
  - Runtime'da explicit verilen `PLUME_STATE_DIR` ve `PLUME_LOG_DIR` degerleri env-file tarafindan override edilmez.
- Gerekce:
  - Native mode sistem orkestrasyonu icin docker-compose benzeri tek bir global env sozlesmesi gerekiyor.
  - Komutlarda surekli `--env-file` verme ihtiyacini kaldirmak hedeflendi.
- Etki:
  - Native mode konfigurasyonu artik sistem-seviyesinde tek noktadan yonetilebilir.
  - Test/runtime izolasyonunda explicit state dizini guvencesi korunur.

## 2026-04-03 - D-062 - Global Env Commands (`env where|init`) for Native Operations

- Durum: accepted
- Karar:
  - Yeni komut ailesi eklendi:
    - `env where`
    - `env init [--force] [--from=/path/.env.example]`
  - Bu komutlar global native env dosyasini (`~/.config/plume/.env`) discover/init etmek icin standart yol olur.
- Gerekce:
  - Native mode sistem orkestrasyonunda kullanicinin surekli `--env-file` vermemesi ve env lokasyonunun deterministic olmasi isteniyor.
- Etki:
  - Kurulum akisi sadeleşti: `env init` + normal plume komutlari.
  - Adapter tarafinda env discover/init adimi tek komutla otomatiklestirilebilir hale geldi.

## 2026-04-03 - D-063 - Built-in Native Core `.env.example` Template

- Durum: accepted
- Karar:
  - Plume repository icine built-in native core env template eklendi:
    - `templates/native-core.env.example`
  - `env init` ve varsayilan global env bootstrap source sirasina built-in template dahil edildi.
- Gerekce:
  - Kullanici her seferinde sifirdan env yazmadan php/nginx/mariadb/redis/horizon benzeri core stack'i hizli baslatabilmeli.
- Etki:
  - Native mode onboarding hizi artis.
  - `env init` komutu artik repository icindeki hazir profile dayanarak calisabilir.

## 2026-04-03 - D-064 - Service Contract PHP Target Alias Normalization + Env Override Precedence

- Durum: accepted
- Karar:
  - `services` komutlarinda tekil hedef normalize/resolve akisi genisletildi:
    - `php84`, `php82`, `php-fpm-8.4` gibi hedefler canonical `php` servisine normalize edilir.
    - hedeften PHP version otomatik cozumlenir ve `up/status/health/logs` akislari bu versiyonla calisir.
  - Laradock bridge `php` service mapping'i, hedeflenen PHP versiyonu verildiginde (`PLUME_SERVICE_VERSION`) var olan `php-fpm-<version>` servisine yonlenebilir.
  - `plume_load_env` guncellendi:
    - komut calisirken disaridan verilen `PLUME_*` ve `PMA_*` env degerleri global `.env` source adiminda ezilmez.
- Gerekce:
  - Kullanici tarafinda mode'dan bagimsiz tek adapter-contract deneyimi beklentisi var.
  - PHP matrix hedeflerini servis adindan dogrudan verebilmek (`php84`) operasyon UX'ini sadeleştirir.
  - Global env source nedeniyle command-scope override'larin bozulmasi test/operasyon kaosu olusturuyordu.
- Etki:
  - `services up/status/health/logs` komutlari PHP alias hedeflerinde daha tutarli ve deterministic.
  - Native/laradock bridge parity adiminda contract uyumu guclendi.
  - Env onecelik modeli daha guvenli hale geldi (CLI override > global env).

## 2026-04-03 - D-065 - Native Host PHP Version Shims (`php8.4` / `php-fpm-8.4`)

- Durum: accepted
- Karar:
  - `php shim` komut ailesi eklendi:
    - `php shim install`
    - `php shim env`
    - `php shim list`
    - `php shim remove`
  - Shim install, `PLUME_PHP_INSTALLED_VERSIONS` listesinden executable wrapper dosyalari uretir:
    - `php8.4`, `php84`
    - `php-fpm-8.4`, `php-fpm84`
  - Wrapper komutlari `php shim run` uzerinden host'taki hedef surum binary'sini arar ve exec eder.
  - Varsayilan `php` binary davranisi degistirilmez; yalnizca versiyonlu komutlar aktif edilir.
- Gerekce:
  - Kullanici beklentisi: terminalde dogrudan `php8.4 -v` ve `php-fpm-8.4 -v` calistirabilmek.
  - Ayni anda default native `php` komutunun mevcut host ayariyla korunmasi gerekiyor.
- Etki:
  - Native mode parity'de laradock benzeri coklu PHP deneyimi CLI seviyesinde guclendi.
  - Surumlu PHP/FPM cagri senaryolari PATH tabanli, portable ve geri alinabilir hale geldi.

## 2026-04-03 - D-066 - `init shell` Idempotent Bootstrap for PHP Shims

- Durum: accepted
- Karar:
  - Yeni komut eklendi: `init shell`
    - `--shell=zsh|bash`
    - `--rc=/path/to/rc`
    - `--force`
  - Komut, once `php shim install` calistirir; sonra hedef rc dosyasina su blok'u idempotent yazar:
    - `# >>> plume php shim >>>`
    - `eval "$(<plume-exec> php shim env)"`
    - `# <<< plume php shim <<<`
  - Tekrar calistirmada duplicate block olusmaz; `--force` ile block refresh edilir.
- Gerekce:
  - Kullanici, her terminal acilisinda versiyonlu komutlari (`php8.4`, `php-fpm-8.4`) manuel `eval` olmadan kullanmak istiyor.
  - Default `php` davranisini bozmadan otomatik ve guvenli bir setup gerekiyor.
- Etki:
  - Onboarding tek komuta indi: `./plume.sh init shell`.
  - Shell entegrasyonunda deterministic ve geri alinabilir bir model saglandi.

## 2026-04-03 - D-067 - Multi-Version Shell Alias Export (zsh/bash Compatible)

- Durum: accepted
- Karar:
  - `php shim env` cikti kapsamı genisletildi:
    - PATH export satirina ek olarak default disi tum kurulu PHP surumleri icin alias satirlari da basar.
    - Format:
      - `alias php81='php8.1'`
      - `alias phpfpm81='php-fpm-8.1'`
  - Default PHP surumu icin alias uretilmez; `php` komutu host native default olarak kalir.
- Gerekce:
  - Ayni makinede birden fazla projede farkli PHP surumu kullanimi icin hizli ve shell-native kisayollar gerekiyor.
  - zsh ve bash icin ortak, portable bir alias modeli hedefleniyor.
- Etki:
  - Kullanici `php81`, `php82`, `php84`, `phpfpm81` gibi kisayollari shell'de dogrudan kullanabilir.
  - Default `php` davranisi bozulmadan multi-version UX gelistirildi.

## 2026-04-03 - D-068 - `doctor php` Diagnostics for Binary Compatibility

- Durum: accepted
- Karar:
  - Yeni alt komut eklendi: `doctor php [--strict]`.
  - Komut, `PLUME_PHP_INSTALLED_VERSIONS` listesindeki her surum icin:
    - CLI binary bulunurlugu
    - FPM binary bulunurlugu
    - role (`default|extra`)
    bilgisini tablo olarak raporlar.
  - `--strict` modunda herhangi bir surumde cli/fpm binary eksigi varsa `exit 2` doner.
- Gerekce:
  - `php8.4`/`php-fpm-8.4` gibi shim komutlarin askida kalmasi veya not-found durumlarini proaktif gormek gerekiyor.
  - Multi-project multi-version ortamda hizli compatibility audit ihtiyaci var.
- Etki:
  - Operasyonel troubleshooting hizlandi.
  - Shell shim + native php matrix modelinde fail-fast kontrol noktasi eklendi.

## 2026-04-03 - D-069 - Native `services install php` -> Real Host Binary Provisioning

- Durum: accepted
- Karar:
  - Native modda `services install php --version=<x.y>` artik sadece state hook degil, gercek host kurulumunu dener.
  - Kurulum driver modeli:
    - macOS: `brew install php@x.y`
    - Linux (apt): `apt install phpx.y-cli phpx.y-fpm`
    - Linux (dnf): su an manual yonlendirme (version-specific otomasyon backlog)
  - Kurulumdan sonra cli/fpm binary bulunurlugu dogrulanir.
  - Basarili kurulumda surum php matrix state'ine (`php.env`) otomatik kaydedilir ve alias seti guncellenir.
  - Install privilege semantigi OS-aware yapildi:
    - Linux: root/sudo gerekir
    - macOS+brew: root yerine normal kullanici gerekir
- Gerekce:
  - Kullanici beklentisi, php version matrix'inin plume tarafindan hosta gercekten provision edilmesi.
  - `doctor php --strict` raporundaki eksik binary'leri dogrudan `services install php` ile kapatabilmek.
- Etki:
  - Native mode parity seviyesi artti; php servis contract'i provisioning yetenegi kazandi.
  - Multi-project farkli PHP versiyonu senaryosunda plume tek komutla kurulum + kayit + kontrol akisini sunar.

## 2026-04-03 - D-070 - Native `services up php` Auto-Provision for Missing Versions

- Durum: accepted
- Karar:
  - Native modda `services up php --version=<x.y>` akisi genisletildi:
    - hedef surum php matrix'te yoksa veya host cli/fpm binary eksikse auto-provision tetikler.
    - auto-provision adimlari:
      1. install privilege kontrolu (OS-aware)
      2. host package install denemesi (`brew|apt|...`)
      3. cli/fpm binary verify
      4. php matrix state (`php.env`) register
    - sonra normal start hook calisir.
- Gerekce:
  - Kullanicinin tek komut deneyimi beklentisi: `services up` hem hazirlar hem calistirir.
  - Multi-project ortamda surum gecislerini manuel install adimina baglamak operasyon maliyetini artiriyor.
- Etki:
  - `services up php` artik daha self-healing ve onboarding-dostu.
  - `services install php` hala acik bir provisioning komutu olarak korunur; `up` onu gerektiginde otomatik devreye alir.

## 2026-04-03 - D-071 - PHP Extension Matrix (Per-Version Isolation + Auto-Sync)

- Durum: accepted
- Karar:
  - Extension konfigurasyonu unified env contract'a eklendi:
    - `PLUME_PHP_EXTENSIONS_GLOBAL`
    - `PLUME_PHP_EXTENSIONS_81`, `PLUME_PHP_EXTENSIONS_82`, `...`
    - `PLUME_PHP_EXTENSIONS_STRICT`
    - `PLUME_PHP_EXTENSIONS_AUTO_SYNC`
    - `PLUME_PHP_EXT_INSTALL_DRIVER`
  - Yeni komutlar:
    - `php ext sync <version|all> [--strict|--no-strict]`
    - `php ext doctor [--strict]`
    - `doctor php-ext [--strict]`
  - `services up php` akisinda binary hazirlama sonrasi extension auto-sync calisir (toggle ile).
- Gerekce:
  - PHP extension'lar surum-bazli izole yonetilmelidir; "bir kere kur hepsinde calissin" modeli guvenilir degildir.
  - Site bazli farkli PHP runtime seciminde extension parity garanti edilmelidir.
- Etki:
  - Native multi-project/multi-version senaryosu extension seviyesinde deterministic hale geldi.
  - Deploy oncesi/sonrasi extension uyumlulugu `doctor php-ext --strict` ile fail-fast kontrol edilebilir.

## 2026-04-03 - D-072 - Native Site Upstream Resolution for Per-Version PHP-FPM

- Durum: accepted
- Karar:
  - Site publish pipeline'inda native mode upstream resolve guclendirildi:
    - per-version override env desteklendi:
      - `PLUME_NATIVE_PHP_FPM_UPSTREAM`
      - `PLUME_NATIVE_PHP_FPM_UPSTREAM_<major><minor>`
    - override yoksa native socket auto-discovery dener:
      - Linux: `/run/php/phpX.Y-fpm.sock`
      - macOS: `/opt/homebrew/var/run/php@X.Y-fpm.sock` vb.
  - Server-specific render uyarlamasi:
    - nginx: `fastcgi_pass unix:/...sock`
    - caddy: `php_fastcgi unix//...sock`
    - apache2: `SetHandler "proxy:unix:/...sock|fcgi://localhost/"`
- Gerekce:
  - Proje bazli PHP runtime seciminde webserver config'in dogru version-specific FPM endpoint'e baglanmasi kritik.
  - `php82-fpm:9000` benzeri container adlari native modda her zaman gecerli degil.
- Etki:
  - Native mode site routing parity daha gercekci ve production'a yakin oldu.
  - Version izolasyonu webserver config seviyesinde de korunur hale geldi.

## 2026-04-04 - D-073 - PHP Extension Auto-Sync Profiles + Native Env Presets

- Durum: accepted
- Karar:
  - `services up php` extension auto-sync davranisi profile tabanli hale getirildi:
    - `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=matrix|target|default`
    - default: `matrix`
  - Native preset env dosyalari eklendi:
    - `templates/native-local.env.example` -> profile `matrix`
    - `templates/native-prod.env.example` -> profile `target`
  - Dokumantasyon guncellendi:
    - `docs/commands/env.md`
    - `docs/commands/global.md`
    - `docs/commands/services.md`
    - `docs/commands/php.md`
    - `docs/operations/env-contract.md`
- Gerekce:
  - Local ortamda tum matrix extension parity'si (dev ergonomisi) istenirken,
    production'da hedef surume odakli sync daha hizli ve daha az risklidir.
- Etki:
  - Tek komut deneyimi korunarak profile bazli, deterministik extension sync kapsam kontrolu saglandi.
  - Local/prod onboarding hizlandi; kullanici dogrudan preset dosyasini `env init --from=...` ile uygulayabilir.

## 2026-04-04 - D-074 - Native Web Server Reload Validation Gate

- Durum: accepted
- Karar:
  - Native `site publish --reload` akısına config validation gate eklendi:
    - nginx: `nginx -t`
    - apache2: `apachectl -t` veya `httpd -t`
    - caddy: `caddy validate`
  - Yeni env toggle:
    - `PLUME_SITE_RELOAD_VALIDATE=true|false` (default: `true`)
  - Validation fail olursa reload atlanır ve reload adımı fail sayılır.
  - `PLUME_SITE_RELOAD_REQUIRED=true` ise publish komutu fail-fast (`exit 2`) döner.
- Gerekce:
  - Geçersiz web server config ile reload denemek çalışma ortamını destabilize eder.
  - Site publish güvenilirliğinde fail-fast doğrulama production parity için kritiktir.
- Etki:
  - Native web server adapter davranışı daha güvenli ve deterministik hale geldi.
  - Hatalı configlerde reload yapılmadığı garanti altına alındı.

## 2026-04-04 - D-075 - Native Nginx Strict Publish Pipeline

- Durum: accepted
- Karar:
  - Yeni strict toggle eklendi:
    - `PLUME_SITE_NGINX_STRICT=true|false` (default: false)
    - `PLUME_NGINX_INCLUDE_DIR=/path` (opsiyonel explicit include target)
  - Native `server=nginx` publish'te strict açıkken:
    1. render edilen snippet gerçek include target'a yazılır,
    2. `nginx -t` lint çalışır,
    3. reload çalışır,
    4. lint/reload fail olursa include dosyası rollback edilir.
  - Site remove akışında strict açıkken hedef include dosyası da kaldırılır; lint/reload best-effort tetiklenir.
- Gerekce:
  - Sadece plume cache'ine yazmak gerçek nginx runtime parity için yeterli değildir.
  - Üretim benzeri güvenilir publish için include target + lint + reload zinciri tek operasyon olmalıdır.
- Etki:
  - Native nginx publish daha gerçekçi ve güvenli hale geldi.
  - Yanlış config/bozuk reload durumunda otomatik geri alma ile kesinti riski azaltıldı.

## 2026-04-04 - D-076 - Site-Level PHP Upstream Override Contract

- Durum: accepted
- Karar:
  - `site add/update` komutlarına `--php-upstream=<host:port|unix:/sock>` eklendi.
  - Site kaydına yeni alan eklendi: `php_upstream`.
  - Render akışında upstream çözümü:
    - `php_upstream` doluysa doğrudan onu kullan.
    - boşsa mevcut resolver (`php_version` + mode/env contract) ile üret.
  - `site check` çıktısı genişletildi:
    - `php_upstream`
    - `php_upstream_resolved`
- Gerekce:
  - Proje/site bazlı PHP routing ihtiyaçları sadece sürüm bazlı resolver ile her zaman ifade edilemez.
  - `fastcgi_pass` seviyesinde explicit override, geçiş ve debug süreçlerini hızlandırır.
- Etki:
  - Site onboarding akışı daha dinamik hale geldi.
  - Per-site PHP upstream yönetimi ve görünürlüğü arttı.

## 2026-04-05 - D-077 - Strict Nginx Publish + `--reload` Dedup

- Durum: accepted
- Karar:
  - Native `PLUME_SITE_NGINX_STRICT=true` publish pipeline'ı reload adımını zaten çalıştırdığı için
    `site publish --reload` çağrısındaki ikinci reload adımı skip edilir.
  - Komut çıktısına bilgi mesajı eklendi:
    - `site reload skipped: already reloaded in strict publish pipeline`
- Gerekce:
  - Aynı publish operasyonunda ikinci reload gereksiz operasyon yükü ve gereksiz log gürültüsü oluşturur.
- Etki:
  - Strict publish davranışı daha deterministik ve daha az yan etkiyle çalışır.

## 2026-04-05 - D-078 - Strict Publish Contract Extended to Apache2/Caddy

- Durum: accepted
- Karar:
  - Native strict publish contract'i nginx dışına genişletildi:
    - apache2: `PLUME_SITE_APACHE2_STRICT`, `PLUME_APACHE2_INCLUDE_DIR`
    - caddy: `PLUME_SITE_CADDY_STRICT`, `PLUME_CADDY_INCLUDE_DIR`
  - Her iki server için strict pipeline:
    1. snippet hedef include path'e sync,
    2. config lint,
    3. reload,
    4. fail olursa rollback.
  - `site publish --reload` ile strict birlikte kullanıldığında duplicate reload engeli korunur.
- Gerekce:
  - Web server parity hedefinde strict davranışın sadece nginx'te kalması contract dengesizliği yaratır.
- Etki:
  - Native web server adapter contract'i nginx/apache2/caddy için simetrik hale geldi.

## 2026-04-17 - D-079 - Hybrid PHP Extension Contract (Preset + Toggle + Matrix)

- Durum: accepted
- Karar:
  - Extension cozumleme katmani hibrit modele tasindi:
    - preset: `PLUME_PHP_EXT_PRESET`, `PLUME_PHP_EXT_PRESET_<ver>`
    - toggle: `PLUME_PHP_EXT_ENABLE_*`, `PLUME_PHP_EXT_ENABLE_<ver>_*`, `PLUME_PHP_EXT_DISABLE_<ver>_*`
    - matrix: `PLUME_PHP_EXTENSIONS_GLOBAL`, `PLUME_PHP_EXTENSIONS_<ver>`
  - Cozumleme sirasi:
    - `preset + matrix + enable - disable`
    - disable toggle son soz sahibidir.
  - Yeni komut:
    - `php ext resolve <version|all>` (nihai extension setini gozlemlenebilir yapar)
- Gerekce:
  - Salt matrix modeli guclu ama onboarding UX'i zayif.
  - Salt boolean toggle modeli ise ileri seviye esneklikte yetersiz.
  - Hibrit model hem kolay baslangic hem ileri kontrol sunar.
- Etki:
  - Extension yonetimi daha adaptif ve projeler arasi tekrar kullanilabilir hale geldi.
  - `services up php` auto-sync davranisi, ayni contract uzerinden deterministik calisir.

## 2026-04-25 - D-080 - Site Check Strict Visibility Contract

- Durum: accepted
- Karar:
  - `site check` ciktisina strict publish gorunurlugu eklendi:
    - `mode`
    - `strict_enabled`
    - `strict_include_dir`
    - `strict_include_target`
  - Hem text hem JSON cikti kontratinda bu alanlar bulunur.
- Gerekce:
  - Operasyonel debug sirasinda "strict aktif mi, hangi include target kullaniliyor?" sorusu tek komutta yanitlanmali.
- Etki:
  - Site-level diagnosability ve mode-aware debug hizi artar.

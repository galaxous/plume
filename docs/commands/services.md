# `services` Commands

## Amac

Native veya container modunda servisleri kurmak ve yonetmek.

## Kullanim

```bash
./plume.sh services supported
./plume.sh services supported --mode=native
./plume.sh services supported --mode=docker-lite
./plume.sh --json services supported --mode=native
./plume.sh services status
./plume.sh services status --running
./plume.sh services status --running --wide
./plume.sh services status --watch
./plume.sh services status --watch=5 --running
./plume.sh services status @web --mode=laradock-bridge
./plume.sh --json services status
./plume.sh services install php
./plume.sh services install all
./plume.sh services up php
./plume.sh services up php84
./plume.sh services status php-fpm-8.4
./plume.sh services health php82
./plume.sh services up all
./plume.sh services up @queue
./plume.sh services down php
./plume.sh services down all
./plume.sh services down group:web
./plume.sh services health
./plume.sh services health --running
./plume.sh services health --watch
./plume.sh services health redis --mode=native
./plume.sh services health @web --mode=laradock-bridge
./plume.sh services logs redis --tail=50 --mode=native
./plume.sh services logs @web --running --mode=laradock-bridge
./plume.sh services logs php --follow --mode=laradock-bridge
./plume.sh services logs php --watch --mode=laradock-bridge
./plume.sh services exec workspace --mode=docker-lite
./plume.sh services exec workspace bash --mode=docker-lite
./plume.sh services exec composer --mode=laradock-bridge
./plume.sh services containers --mode=docker-lite
./plume.sh services containers --mode=laradock-bridge
./plume.sh services containers nginx --mode=docker-lite
./plume.sh services laradock init --mode=laradock-bridge --path=/opt/laradock
./plume.sh services laradock sync --mode=laradock-bridge --path=/opt/laradock
./plume.sh services laradock check --mode=laradock-bridge --path=/opt/laradock
./plume.sh services config show --mode=laradock-bridge
./plume.sh services config add @web --mode=laradock-bridge
./plume.sh services config remove redis --mode=laradock-bridge
./plume.sh services config reset --mode=laradock-bridge
./plume.sh services workspace status --mode=docker-lite
./plume.sh services workspace up --mode=docker-lite
./plume.sh services workspace apply --mode=docker-lite
./plume.sh services workspace refresh --mode=docker-lite
./plume.sh services workspace down --mode=docker-lite
./plume.sh services workspace init --mode=docker-lite --path=/abs/project
./plume.sh services workspace reinit --mode=docker-lite --path=/abs/project
./plume.sh services web sync-config --reload
./plume.sh services web port 80 --reload
./plume.sh services update
./plume.sh services install php --version=8.3
./plume.sh services up horizon --version=latest
```

## Parametreler

- hedef servis: `all`, servis adi (`php`, `redis`, `mariadb`, `mysql`, `phpmyadmin`, `postgres`, `mongodb`, `rabbitmq`, `mongo_webui`, `redis_webui` vb.) veya servis grubu (`@core`, `@web`, `@db`, `@cache`, `@queue`, `group:web`)
  - adapter-contract aliaslari mode'dan bagimsiz kabul edilir:
    - `php-fpm -> php`
    - `workspace -> composer`
    - `php-worker -> php_worker`
    - `laravel-horizon -> horizon`
    - php hedef aliaslari: `php84`, `php-fpm-8.4`, `php82`, `php-fpm-8.2`
      - bu hedefler `php` servisine normalize edilir ve ilgili PHP versiyonu otomatik cozumlenir
- `supported` icin:
  - `--mode=native|docker-lite|laradock-bridge`
  - metin cikti sonunda mode'a uygun group listesi de verilir
- `status`:
  - `enabled`, `running`, `health`, `port`, `version` alanlarini verir
  - `--running` / `--running-only` / `--active`: yalnizca `running=true` servisleri gosterir
  - `--wide`: text tabloda port listesini kisaltmadan tam basar
  - `--watch[=N]`: text ciktisini her `N` saniyede (varsayilan `2`) yeniler
  - watch modunda ustte refresh araligi ve son guncelleme zamani yazdirilir
  - grup hedefi verilirse (`@web`, `group:queue`) yalnizca o grubun servislerini listeler
  - web server satiri `web` yerine `nginx|apache2|caddy` olarak gosterilir
  - native/docker-lite modlarinda yalnizca aktif driver (`PLUME_WEB_SERVER_DRIVER`) `enabled=true` olur
  - laradock-bridge modunda `enabled`, env toggle degil compose-varligi semantigi ile hesaplanir
  - laradock-bridge text output'unda aktif `MODE` ve `CONTEXT` basliklari da yazdirilir
  - laradock-bridge modunda `PORT` sutunu tek port yerine tum published host portlarini (`80,443`, `2222,3000`) gosterebilir
- `health`:
  - hedef servis verilmezse tum servisleri listeler
  - `--running` / `--running-only` / `--active`: yalnizca `running=true` servisleri listeler
  - `--watch[=N]`: text ciktisini her `N` saniyede (varsayilan `2`) yeniler
  - watch modunda ustte refresh araligi ve son guncelleme zamani yazdirilir
  - web server health gorunumu `nginx|apache2|caddy` satirlariyla verilir
  - grup hedefi verilirse (`@web`, `group:db`) yalnizca o grubun servislerini listeler
- `logs`:
  - `services logs <service> [--tail=N]`
  - grup ve `all` hedefleri kabul eder (`@web`, `@queue`, `all`)
  - `--follow` / `-f`: log stream'i acik tutar
  - `--watch`: `--follow` alias'i
  - `--running` / `--running-only` / `--active`: yalnizca calisan servislerin loglarini okur
- `exec`:
  - `services exec <service> [--cmd=sh|bash] [--no-tty] [-- ...]`
  - kisayol: `services exec <service> <cmd> [args...]` (ornek: `services exec workspace bash`)
  - docker-lite ve laradock-bridge modlarinda `docker compose exec` calistirir
  - varsayilan shell `sh`'dir
  - `composer` alias'i `workspace` container'ina yonlendirilir
  - native modda bloklanir
- `containers`:
  - `services containers [service] [--mode=docker-lite|laradock-bridge] [--path=...]`
  - docker-lite/laradock-bridge compose konteynerlerini `docker compose ps` ile listeler
  - native modda bloklanir
- `laradock`:
  - `services laradock init|sync|check --mode=laradock-bridge [--path=...] [--repo=...] [--branch=...]`
  - `init`: varsayilan `https://github.com/laradock/laradock.git` reposunu clone eder (veya mevcut repoda pull/sync), mode path'i laradock-bridge olarak kaydeder.
  - `sync`: git fetch/pull ile laradock repo gunceller (repo url override destekler).
- `web` (native, nginx driver):
  - `services web sync-config [--port=80] [--dry-run] [--reload]`
  - `services web port <n> [--dry-run] [--reload]`
  - Ana Homebrew `nginx.conf` listen portunu yedekleyip gunceller; `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true` gerekir. Bkz. [services-web.md](services-web.md).
  - `check`: strict konfigurasyon kontrolu yapar:
    - gerekli servisler compose dosyasinda var mi (`nginx,apache2,caddy,mariadb,mysql,phpmyadmin,php-fpm,redis,laravel-horizon,php-worker,workspace`)
    - `.env` icinde `APP_CODE_PATH_CONTAINER=/var/www` uyumlu mu
    - `APP_CODE_PATH_HOST` cozumlenebiliyor mu
    - laradock-bridge modundaki kayitli site path'leri `APP_CODE_PATH_HOST` kapsaminda mi
- `config`:
  - `services config show|add|remove|reset --mode=laradock-bridge`
  - SQLite icindeki desired service set'ini yonetir
  - `show`: aktif Laradock context icin `desired` ve `resolved` servis setlerini ayri ayri listeler
  - `add/remove`: tek servis (`php`, `redis`, `workspace`) veya grup (`@web`, `@db`, `@queue`, `@core`) kabul eder
  - `reset`: ilgili Laradock context icin desired service set'ini temizler
- Laradock runtime kurali:
  - `services status|health|logs|up|down|exec|containers --mode=laradock-bridge` once gecerli Laradock context ister.
  - Path onceligi:
    - `--path=/abs/laradock`
    - `mode path set laradock-bridge /abs/laradock`
  - Path tahmin edilmez; gecerli path yoksa komut fail-fast olur.
  - Runtime source-of-truth canli `docker compose` durumudur; state env/SQLite cache olarak kullanilir.
  - `services status` ve `services supported` Laradock'ta static Plume listesi degil, compose icindeki service listesini gosterir.
  - `services up all` ve `services down all` Laradock'ta compose icindeki tum servisleri degil, SQLite'da tutulan desired service set'ini hedefler.
  - `services up all` safe-order ile calisir: `db -> php -> queue -> web -> others`.
  - `services down all` ters safe-order ile calisir: `web -> queue -> php -> db -> others`.
  - `services up all` sirasinda bir servis fail olursa, bu komutta daha once baslatilan servisler ters sirada rollback ile stop edilir.
  - Desired set bos ise `up/down all` fail eder; once `services config add ...` ile servis seti tanimlanmalidir.
  - `depends_on` ile gelen bagimliliklar desired sete yazilmaz; sadece resolved sete dahil edilir.
  - Bu sayede kullanici niyeti (`desired`) ile compose dependency graph'i (`resolved`) birbirine karismaz.
  - group hedefleri de desteklenir:
    - `@core`: temel laravel runtime yuzeyi (`workspace`, `php-fpm`, `php-worker`, `laravel-horizon`, aktif web/db baglantilari)
    - `@web`: web server servisleri (`nginx`, `apache2`, `caddy`, `openresty`)
    - `@db`: veritabani/broker/cache servisleri (`mariadb`, `mysql`, `postgres`, `redis`, `rabbitmq` vb. compose'ta varsa)
    - `@queue`: queue worker/horizon servisleri
  - Alias komutlar yine desteklenir:
    - `php` -> `php-fpm`
    - `composer` -> `workspace`
    - `horizon|supervisor` -> `laravel-horizon`
  - `enabled` hesabi mode-izole calisir:
    - native/docker-lite: Plume env toggle'lari
    - laradock-bridge: Laradock compose icinde service var mi
- `workspace`:
  - `services workspace init|reinit|apply|up|refresh|rebuild|down|status --mode=docker-lite [--path=/abs/project] [--profile=<name>]`
  - docker compose lifecycle komutlarini toplu workspace seviyesinde calistirir
  - `reinit`: mevcut plume docker-lite stub dosyalarini temizleyip yeniden `init` eder
  - `apply`: degisiklikleri algilar ve otomatik karar verir
    - context/build etkili degisiklik: `up -d --force-recreate --build`
    - config/.env/conf degisikligi: `up -d --force-recreate`
    - container down ise: `up -d`
    - degisiklik yoksa: no-op
  - `refresh` (`rebuild` alias): `docker compose up -d --force-recreate --build` calistirir
  - PHP matrix reconcile (otomatik):
    - `PLUME_PHP_DEFAULT_VERSION` + `PLUME_PHP_INSTALLED_VERSIONS` degerlerinden istenen `php-fpm` servis seti hesaplanir.
    - Gerekli servisler (`php-fpm`, `php81-fpm`, `php82-fpm`, `php83-fpm`, `php84-fpm`) otomatik `up` edilir.
    - Env'den cikarilan (obsolete) php-fpm clone servisler `rm -f -s` ile temizlenir.
    - `services workspace up` komutunda `.env.docker-lite` php/workspace degisimi algilanirsa otomatik `--force-recreate --build` moduna gecilir.
- `--version`:
  - `services install|up|update` komutlarinda secilebilir.
  - `horizon` icin `--version` ve service env versiyonlari ile bagimsiz calisir.
- `update` icin:
  - configte `false -> true` gecen servisleri algilar
  - yeni enable olan servisleri kurar ve baslatir (policy'ye gore)
- Bagimlilik kurali:
  - `horizon` icin `supervisor` zorunlu (native mode)
  - `phpmyadmin` icin `PMA_DB_ENGINE` (`mariadb|mysql`, alias: `PMA_ENGINE`) secimi zorunlu; secili engine `enabled=true` olmalidir
- Phase 2 notu (guncel):
  - Varsayilan (`PLUME_NATIVE_HOST_PROVISION=false`): non-PHP servisler state/port orchestration kullanir.
  - `PLUME_NATIVE_SERVICE_AUTO_PROVISION=true` (default): native modda `enabled=true` servisler `services up` ile host install+start (Phase 17); `--no-provision` ile kapatilir.
  - `PLUME_NATIVE_HOST_PROVISION=true`: tum desteklenen servisler icin gercek host kurulum/start/stop (brew/apt/dnf + npm web UI).
  - Native **mailpit** (D-109): macOS Homebrew `brew install mailpit` + `brew services start mailpit`; `services up mailpit` global provision bayragi olmadan da brew yolunu dener. Linux native: WARN + exit 2; docker-lite veya manuel kurulum.
  - Native `php` icin `services install php --mode=native --version=<x.y>` gercek host binary kurulumunu dener:
    - macOS (brew): `php@x.y`
    - Linux (apt): `phpx.y-cli` + `phpx.y-fpm`
  - Native `services up php82` / `services up php --version=8.2` (ve diger surum aliaslari) binary dogrulamasinin ardindan host FPM servisini baslatir:
    - macOS (brew): `brew services start php@8.2` (formul kurulu degilse `php@x.y` adi kullanilir; default surum icin kurulu `php` formulune dusulebilir)
    - Baslatmadan once Homebrew `www.conf` pool `listen` Plume canonical unix socket ile hizalanir (D-107); socket yoksa komut `exit 2` ve php-fpm log ipucu.
    - Linux (apt): `systemctl start phpx.y-fpm`
    - `PLUME_PHP_NATIVE_INSTALL_DRIVER=mock` smoke/test ortaminda gercek brew cagrilmaz.
  - Birden fazla PHP surumu ayni anda calisabilir (Homebrew: surum basina ayri unix socket, or. `php@8.2-fpm.sock`). Plume bir surumu baslatirken diger surumleri durdurmaz; site nginx upstream'i surume ozel socket veya `--php-upstream` ile hedeflenmelidir (bkz. D-105). `services up php82` Homebrew pool `listen` satirini bu socket yoluna ayarlar (bkz. D-107).
- `--version` davranisi:
  - `plume` için alias veya direkt surum ile `php` calistirilabilir (`php`, `php83`, `8.3`).
  - php disi servislerde `latest` veya semver/metin formatinda surum kabul edilir (stub fazinda validate katidir).

## Cikti / Exit Codes

- `0`: islem basarili
- `2`: prereq/validation hatasi

## Ornekler

```bash
./plume.sh services install php
./plume.sh services up php
./plume.sh services up php82
./plume.sh services up php --version=8.2
./plume.sh services down php
./plume.sh services health php
./plume.sh services logs php --tail=20
./plume.sh services update
./plume.sh services status
./plume.sh services supported --mode=native
```

## Native Runtime Notlari (Phase 6)

- Native `install/up` adimlarinda servis bazli runtime state `~/.config/plume/state/services_runtime_native.env` dosyasinda tutulur.
- Native install yetki semantigi:
  - Linux: host package install icin root/sudo gerekir.
  - macOS + brew: install komutu normal kullanici ile calistirilir (brew root'ta calismaz).
- Native `services up php --version=<x.y>`:
  - hedef PHP surumu matrix'te yoksa veya host cli/fpm binary eksikse auto-provision tetikler.
  - auto-provision basariliysa surum `php.env` state'ine eklenir ve servis start devam eder.
  - macOS Homebrew: hedef surum icin `brew services start php@x.y` calistirilir (`php82` alias → `8.2`).
  - Homebrew FPM: `services up` oncesi `www.conf` `listen` canonical unix socket ile guncellenir; basarisiz bind/socket yoksa `exit 2` (D-107).
  - Diger surumlerin FPM'i (or. php@8.3) otomatik durdurulmaz; coklu surum unix socket ile birlikte calisabilir.
- Native `services up php` (versiyon belirtilmez) varsayilan olarak tum PHP matrix'ini enforce eder:
  - `PLUME_PHP_INSTALLED_VERSIONS` + default surumun tamamini binary bazinda dogrular/provision eder.
  - Toggle: `PLUME_PHP_AUTOPROVISION_ALL_ON_UP=true|false` (default: true).
- Native `services up php` extension auto-sync:
  - `PLUME_PHP_EXTENSIONS_AUTO_SYNC=true` ise extension contract'i (preset + toggle + matrix) sync/verify edilir.
  - `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE`:
    - `matrix` (default): `PLUME_PHP_INSTALLED_VERSIONS + default` tum surumler sync edilir.
    - `target`: sadece `services up php --version=<x.y>` hedef surumu sync edilir.
    - `default`: sadece `PLUME_PHP_DEFAULT_VERSION` sync edilir.
  - strict davranis: `PLUME_PHP_EXTENSIONS_STRICT=true`
- Port kullanan servislerde default port doluysa fallback port secilir ve `services_ports_native.env` dosyasina yazilir.
- `services logs` ciktilari varsayilan olarak `~/.config/plume/logs/services/native/<service>.log` altindan okunur.

## Docker-Lite Runtime Notlari (Phase 7)

- `services install/up/down --mode=docker-lite` komutlari compose service bazli calisir.
- Docker-lite'ta `composer` ayri servis olarak listelenmez; `workspace` container icinde komut olarak kullanilir.
- Docker-lite'ta `supervisor` ve `horizon` ayni `laravel-horizon` container'ina map edilir.
- Compose dosyasi deterministic oncelikle cozumlenir: `--path` > `mode path` > remembered compose > calisma dizini (`docker-compose.yml|compose.yml`).
- `--path` verilmemis olsa bile kayitli `mode path` (`mode path set docker-lite ...`) varsa compose buradan da otomatik cozumlenir.
- `services workspace init --mode=docker-lite --path=...` ile hedef dizine docker-lite stub (compose + web conf + env stub) uretilir.
- `mode=docker-lite` + `mode path` ayarliysa, `<mode-path>/.env.docker-lite` otomatik yuklenir.
- `services workspace up|down|status --mode=docker-lite` ile tum stack lifecycle yonetilir.
- `--profile` verilmezse varsayilan `core` profili kullanilir.
- Docker-lite port davranisi native ile paraleldir: default port doluysa fallback port atanir ve state dosyasina yazilir.
- Web server varsayimi tek aktif web server + varsayilan host portlari `80/443` (`PLUME_WEB_PORT`, `PLUME_WEB_HTTPS_PORT`).
- `services workspace up --mode=docker-lite` once `compose config --images` ile image listesini cikarir, eksik image'lari tek tek `docker pull` ile ceker; pull fail olursa `up` baslamadan fail olur.
- Pull adimi fail olursa `docker search` tabanli benzer image onerileri yazdirilir.
- PHP surumleri degistiginde (`PLUME_PHP_DEFAULT_VERSION`, `PLUME_PHP_INSTALLED_VERSIONS`) `workspace up/apply` otomatik algilar; image eksikse compose pull/up ile indirir, php-fpm ve workspace tarafini rebuild/recreate eder.
- `services health/logs --mode=docker-lite` komutlari docker compose `ps/logs` uzerinden container durumuna baglanir.
- `services exec --mode=docker-lite|laradock-bridge` mode/path bilgisiyle compose dosyasini bulup herhangi bir dizinden container shell'e girebilir.
- `services install/up/workspace up` sonrasinda global mode/path context lock aktif olur; mode/path degisikligi icin `--force` gerekir.

## Mailpit (native, D-109)

macOS Homebrew ile gelistirme mail yakalama:

```bash
# Manifest
# services.yml → mailpit: { enabled: true }
./plume.sh services provision --from-manifest

# veya dogrudan
PLUME_MAILPIT_ENABLED=true ./plume.sh services install mailpit --mode=native
./plume.sh services up mailpit --mode=native
```

- UI varsayilan: `http://127.0.0.1:8025` (`PLUME_MAILPIT_PORT`).
- Laravel `.env`: `MAIL_MAILER=smtp`, `MAIL_HOST=127.0.0.1`, `MAIL_PORT=1025` (Mailpit SMTP).
- Linux native: otomatik kurulum yok; `./plume.sh services up mailpit` WARN + exit 2 — `--mode=docker-lite` veya [Mailpit](https://github.com/axllent/mailpit) manuel.
- Nginx port 80/8080 teshisi (D-109): `./plume.sh doctor web` — bkz. [services-web.md](./services-web.md).

## Manifest alt komutlari (native)

```bash
./plume.sh services manifest show
./plume.sh services provision --from-manifest [--dry-run]
```

- `manifest show`: `effective_*` satirlari (web/php/database + tum registry servisleri icin `effective_<service>_enabled` / `_version`). Bkz. [services-manifest.md](../operations/services-manifest.md), [services-provision.md](./services-provision.md).

## Hata Senaryolari

- Servis desteklenmiyor
- Port atanamadi
- Paket yoneticisi adimi basarisiz
- Istenen versiyon desteklenmiyor
- Horizon baslatilamadi (supervisor eksik/aktif degil)
- `services update` reconcile adiminda kurulum/baslatma hatasi

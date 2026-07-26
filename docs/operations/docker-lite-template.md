# Docker-Lite Template Runbook

Bu dokuman, Laradock mantiginda ama daha hafif bir `docker-compose` template'inin nasil kullanilacagini aciklar.

Template dosyasi:

- `templates/docker-lite/docker-compose.template.yml`

## 1. Stub Uretimi (onerilen)

```bash
./plume.sh services workspace init --mode=docker-lite --path=/abs/project
```

Bu komut su dosyalari hedef dizinde olusturur:

- `docker-compose.yml`
- `conf/nginx.conf`
- `conf/apache2.conf`
- `conf/Caddyfile`
- `mariadb/`
- `mysql/`
- `phpmyadmin/`
- `.env.docker-lite`

Context yapisi Laradock benzeri olacak sekilde servis-bazli `Dockerfile` icerir:

- `workspace/Dockerfile`
- `php-fpm/Dockerfile` (tum PHP-FPM varyantlari ortak)
- `nginx|apache2|caddy/Dockerfile`
- `mariadb|mysql|phpmyadmin|postgres|redis|laravel-horizon/Dockerfile`

Not:

- `mode=docker-lite` ve `mode path` ayarliysa, plume komutlari `/.env.docker-lite` dosyasini otomatik yukler; manuel `source` gerekmez.

## 2. Manuel Baslangic

```bash
cp templates/docker-lite/docker-compose.template.yml ./docker-compose.yml
```

Opsiyonel web server config dosyalari:

- `templates/docker-lite/conf/nginx.conf`
- `templates/docker-lite/conf/apache2.conf`
- `templates/docker-lite/conf/Caddyfile`

## 3. Plume ile Entegrasyon

```bash
./plume.sh mode use docker-lite
./plume.sh mode path set "$PWD"
export PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true
```

Varsayilan servis esleme (gerektiginde override et):

```bash
export PLUME_DOCKER_LITE_WEB_SERVICE=nginx
export PLUME_DOCKER_LITE_PHP_SERVICE=php-fpm
export PLUME_DOCKER_LITE_SUPERVISOR_SERVICE=laravel-horizon
export PLUME_DOCKER_LITE_HORIZON_SERVICE=laravel-horizon
```

## 4. Workspace / Service Lifecycle

```bash
./plume.sh services workspace up --mode=docker-lite
./plume.sh services workspace status --mode=docker-lite
./plume.sh services up php --mode=docker-lite
./plume.sh services health php --mode=docker-lite
./plume.sh services logs php --mode=docker-lite --tail=50
```

## 5. Shared Env Onceligi

Docker-lite template, native ile ortak `PLUME_*` degiskenlerini birincil kaynak olarak kullanir:

- `PLUME_PHP_VERSION`
- `PLUME_WEB_SERVER_VERSION`
- `PLUME_MARIADB_VERSION`
- `PLUME_MYSQL_VERSION`
- `PLUME_POSTGRES_VERSION`
- `PLUME_REDIS_VERSION`
- `PLUME_PHPMYADMIN_VERSION`

`PLUME_DOCKER_LITE_*` degiskenleri yalnizca override/mapping icindir.

phpMyAdmin secici sozlesmesi:

- `PMA_DB_ENGINE=mariadb|mysql`
- `PMA_USER`, `PMA_PASSWORD`, `PMA_ROOT_PASSWORD`
- `PMA_PORT` (host port, varsayilan `8081`)
- `PMA_MAX_EXECUTION_TIME`, `PMA_MEMORY_LIMIT`, `PMA_UPLOAD_LIMIT`

Workspace (lite Laradock davranisi):

- Non-root user: `WORKSPACE_USER`, `WORKSPACE_PUID`, `WORKSPACE_PGID`
- Opsiyonel shell/tooling: `WORKSPACE_INSTALL_ZSH`, `WORKSPACE_INSTALL_NODE`
- Opsiyonel Oh My Zsh: `WORKSPACE_INSTALL_OH_MY_ZSH` (`WORKSPACE_INSTALL_ZSH=true` gerektirir)
- Node/NPM: `WORKSPACE_NODE_VERSION`, `WORKSPACE_NPM_REGISTRY`
- Hazir alias dosyasi: `workspace/aliases.sh` (`c`, `ci`, `cu`, `art`, `pa`, `t`)
- Workspace icinde coklu PHP: `PLUME_PHP_DEFAULT_VERSION` + `PLUME_PHP_INSTALLED_VERSIONS`
- Komutlar: `php81`, `php82`, `php83`, `php84` ve aktif surumu degistirmek icin `phpuse 8.2`
- Otomatik kural: `PLUME_PHP_DEFAULT_VERSION`, `PLUME_PHP_INSTALLED_VERSIONS` icinde yoksa plume listeye otomatik ekler.

## 6. PHP-FPM Coklu Surum (Clone Model)

Template icinde default + clone model:

- Default: `php-fpm` (`PLUME_PHP_VERSION` ile surum secilir)
- Clone servisler:

- `php81-fpm`
- `php82-fpm`
- `php83-fpm`
- `php84-fpm`

Not:

- `php81-fpm`, `php82-fpm`, `php83-fpm`, `php84-fpm` icin ayri context yoktur.
- Tumu `php-fpm/Dockerfile` context'ini kullanir.
- Surum secimi compose `build.args.PHP_VERSION` ile yapilir.

Aktif profil ile baslat:

```bash
docker compose --profile core --profile php83 up -d
```

Plume tarafinda hangi PHP servisine baglanilacagi:

```bash
export PLUME_PHP_VERSION=8.2
export PLUME_DOCKER_LITE_PHP_SERVICE=php-fpm
```

## 7. Image Yoksa Ne Olur

`services workspace up --mode=docker-lite` adiminda:

1. compose image listesi okunur
2. local image varligi kontrol edilir
3. eksik image'lar tek tek pull edilir
4. pull fail olursa benzer image onerileri yazdirilir ve komut fail olur

## 8. Web Server Secimi

- Nginx: `--profile web-nginx`
- Apache2: `--profile web-apache2`
- Caddy: `--profile web-caddy`

Varsayilan davranis:

- Ayni anda tek web server calistirilir (nginx veya apache2 veya caddy).
- Varsayilan web host portlari `80/443`'dur (`PLUME_WEB_PORT`, `PLUME_WEB_HTTPS_PORT`).
- Default `core` profile sadece `php-fpm` acilir; `php83-fpm` gibi clone servisler yalnizca explicit profile ile acilir.
- `composer` islemleri `workspace` container icinde calistirilir (ayri composer service yoktur).
- Queue tarafinda `supervisor` ve `horizon`, ortak `laravel-horizon` container davranisinda eslenir.

Web server servisini plume ile esitle:

```bash
export PLUME_DOCKER_LITE_WEB_SERVICE=nginx
# veya apache2 / caddy
```

# Docker-Lite Template Runbook

This document explains how to use a lighter `docker-compose` template in the Laradock style.

Template file:

- `templates/docker-lite/docker-compose.template.yml`

## 1. Stub Generation (recommended)

```bash
./plume.sh services workspace init --mode=docker-lite --path=/abs/project
```

This command creates these files in the target directory:

- `docker-compose.yml`
- `conf/nginx.conf`
- `conf/apache2.conf`
- `conf/Caddyfile`
- `mariadb/`
- `mysql/`
- `phpmyadmin/`
- `.env.docker-lite`

The context layout is Laradock-like and includes service-based `Dockerfile`s:

- `workspace/Dockerfile`
- `php-fpm/Dockerfile` (shared by all PHP-FPM variants)
- `nginx|apache2|caddy/Dockerfile`
- `mariadb|mysql|phpmyadmin|postgres|redis|laravel-horizon/Dockerfile`

Note:

- When `mode=docker-lite` and `mode path` are set, plume commands load the `/.env.docker-lite` file automatically; manual `source` is not required.

## 2. Manual Start

```bash
cp templates/docker-lite/docker-compose.template.yml ./docker-compose.yml
```

Optional web server config files:

- `templates/docker-lite/conf/nginx.conf`
- `templates/docker-lite/conf/apache2.conf`
- `templates/docker-lite/conf/Caddyfile`

## 3. Integration with Plume

```bash
./plume.sh mode use docker-lite
./plume.sh mode path set "$PWD"
export PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true
```

Default service mapping (override when needed):

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

## 5. Shared Env Precedence

The docker-lite template uses shared `PLUME_*` variables with native as the primary source:

- `PLUME_PHP_VERSION`
- `PLUME_WEB_SERVER_VERSION`
- `PLUME_MARIADB_VERSION`
- `PLUME_MYSQL_VERSION`
- `PLUME_POSTGRES_VERSION`
- `PLUME_REDIS_VERSION`
- `PLUME_PHPMYADMIN_VERSION`

`PLUME_DOCKER_LITE_*` variables are only for override/mapping.

phpMyAdmin selector contract:

- `PMA_DB_ENGINE=mariadb|mysql`
- `PMA_USER`, `PMA_PASSWORD`, `PMA_ROOT_PASSWORD`
- `PMA_PORT` (host port, default `8081`)
- `PMA_MAX_EXECUTION_TIME`, `PMA_MEMORY_LIMIT`, `PMA_UPLOAD_LIMIT`

Workspace (lite Laradock behavior):

- Non-root user: `WORKSPACE_USER`, `WORKSPACE_PUID`, `WORKSPACE_PGID`
- Optional shell/tooling: `WORKSPACE_INSTALL_ZSH`, `WORKSPACE_INSTALL_NODE`
- Optional Oh My Zsh: `WORKSPACE_INSTALL_OH_MY_ZSH` (requires `WORKSPACE_INSTALL_ZSH=true`)
- Node/NPM: `WORKSPACE_NODE_VERSION`, `WORKSPACE_NPM_REGISTRY`
- Ready alias file: `workspace/aliases.sh` (`c`, `ci`, `cu`, `art`, `pa`, `t`)
- Multiple PHP inside workspace: `PLUME_PHP_DEFAULT_VERSION` + `PLUME_PHP_INSTALLED_VERSIONS`
- Commands: `php81`, `php82`, `php83`, `php84` and `phpuse 8.2` to change the active version
- Automatic rule: if `PLUME_PHP_DEFAULT_VERSION` is not in `PLUME_PHP_INSTALLED_VERSIONS`, plume adds it to the list automatically.

## 6. PHP-FPM Multi-Version (Clone Model)

Default + clone model inside the template:

- Default: `php-fpm` (version selected with `PLUME_PHP_VERSION`)
- Clone services:

- `php81-fpm`
- `php82-fpm`
- `php83-fpm`
- `php84-fpm`

Note:

- There is no separate context for `php81-fpm`, `php82-fpm`, `php83-fpm`, `php84-fpm`.
- All use the `php-fpm/Dockerfile` context.
- Version selection is done with compose `build.args.PHP_VERSION`.

Start with an active profile:

```bash
docker compose --profile core --profile php83 up -d
```

Which PHP service Plume connects to:

```bash
export PLUME_PHP_VERSION=8.2
export PLUME_DOCKER_LITE_PHP_SERVICE=php-fpm
```

## 7. What Happens If the Image Is Missing

In the `services workspace up --mode=docker-lite` step:

1. the compose image list is read
2. local image presence is checked
3. missing images are pulled one by one
4. if pull fails, similar image suggestions are printed and the command fails

## 8. Web Server Selection

- Nginx: `--profile web-nginx`
- Apache2: `--profile web-apache2`
- Caddy: `--profile web-caddy`

Default behavior:

- Only one web server runs at a time (nginx or apache2 or caddy).
- Default web host ports are `80/443` (`PLUME_WEB_PORT`, `PLUME_WEB_HTTPS_PORT`).
- The default `core` profile only starts `php-fpm`; clone services such as `php83-fpm` start only with an explicit profile.
- `composer` work runs inside the `workspace` container (there is no separate composer service).
- On the queue side, `supervisor` and `horizon` map to the shared `laravel-horizon` container behavior.

Align the web server service with plume:

```bash
export PLUME_DOCKER_LITE_WEB_SERVICE=nginx
# or apache2 / caddy
```

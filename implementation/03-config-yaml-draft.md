# Config YAML Draft

Amaç: Lokal ve production ortamlari tek sozlesme ile yonetmek.

```yaml
version: 1

project:
  name: myapp
  root: /srv/apps/myapp
  mode: native # native | docker-lite | laradock-bridge
  type: laravel # laravel | generic-php | static
  domains:
    - myapp.test
    - api.myapp.test

sites:
  registry:
    scope: user # user | system
    user_dir: ~/.config/plumectl/sites
    system_dir: /etc/plume/sites
    index_file: index.yaml
  onboarding:
    interactive_by_default: true
    default_server: nginx # nginx | apache2 | caddy
    host_update: ask # always | ask | never
    path_policy: absolute-only # absolute-only | resolve-relative

runtime:
  environment: local # local | production
  platform:
    os: auto # auto | macos | linux
    package_manager: auto # auto | brew | apt | dnf
  env:
    enabled: true
    file: .env
    example_file: .env.example
    prefix: PLUME_
    mode_specific_prefixes:
      native: PLUME_NATIVE_
      docker_lite: PLUME_DOCKER_LITE_
      laradock_bridge: PLUME_LARADOCK_
  php:
    version: "8.3"
    installed_versions:
      - "8.1"
      - "8.2"
      - "8.3"
    default_alias: php # default system alias
    default_version: "8.3"
    aliases:
      php81: "8.1"
      php82: "8.2"
      php83: "8.3"
    composer: true
    xdebug: false
    fpm: true
  node:
    enabled: true
    manager: nvm
    version: "20"
    package_manager: npm

laravel:
  bootstrap:
    composer_install: true
    copy_env: true
    key_generate: true
    storage_link: true
    run_migrations: ask # always | ask | never
    run_seeders: false
    npm_install: ask
    npm_build: ask
  runtime:
    scheduler:
      enabled: true
      driver: cron # cron | systemd-timer
    queue:
      enabled: true
      driver: redis
    horizon:
      enabled: true
      require_supervisor: true
    octane:
      enabled: false
      server: swoole # swoole | roadrunner
    reverb:
      enabled: false
  deploy:
    strategy: atomic-symlink # atomic-symlink | in-place
    maintenance_mode: auto
    migrate: true
    cache_optimize: true
    queue_restart: true
    horizon_terminate: true
    health_gate:
      enabled: true
      endpoint: /up
    rollback_on_fail: true

permissions:
  require_root_for:
    - install
    - uninstall
    - update
    - service-install
    - system-config-write
  prefer_non_root_for:
    - status
    - health
    - logs
    - services-up-down

services:
  profile: minimal-default
  reconcile_on_update:
    detect_toggle_changes: true
    install_on_enable: true
    start_on_enable: true
  web:
    enabled: true
    driver: nginx # nginx | apache2 | caddy
    port: 80
  mysql:
    enabled: false
    version: "8.0"
    port: 3306
  mariadb:
    enabled: true
    version: "11.0"
  postgres:
    enabled: false
    version: "16"
  redis:
    enabled: false
    version: "7"
    port: 6379
  memcached:
    enabled: false
    version: "1.6"
  rabbitmq:
    enabled: false
    version: "3.13"
  mongodb:
    enabled: false
    version: "7"
  mongo_webui:
    enabled: false
  mailpit:
    enabled: false
    port: 1025
    ui_port: 8025
  meilisearch:
    enabled: false
    version: "1.8"
    port: 7700
  minio:
    enabled: false
    api_port: 9000
    console_port: 9001
  supervisor:
    enabled: true
  horizon:
    enabled: true
    require_supervisor: true
  php_worker:
    enabled: true

docker_lite:
  enabled: false
  workspace:
    mount: /var/www
    uid: 1000
    gid: 1000

laradock_bridge:
  enabled: false
  laradock_path: /opt/laradock

observability:
  healthcheck_interval_sec: 30
  log_level: info
  log_dir: /var/log/plume

security:
  firewall_checks: true
  os_security_checks: true # selinux/apparmor vb.

secrets:
  enabled: true
  source_order:
    - env
    - file
  file_path: /etc/plume/secrets.env

tls:
  enabled: true
  strategy: auto # auto | self-signed | acme
  docker_cert_helper: optional
  renew_cron: true

rollback:
  enabled: true
  backup_dir: /var/backups/plume
  keep_last: 5

updates:
  pinned_version: "" # ornek: 1.2.3
  auto_update: false
  channel: stable # stable | beta

prerequisites:
  policy: fail-fast # fail-fast | warn
  auto_install: false
  profiles:
    - base
    - native-install
  required_commands:
    base:
      - bash
      - sed
      - awk
      - grep
      - cut
      - xargs
      - tar
      - gzip
      - curl
    native-install:
      - sudo
    git-ops:
      - git
      - ssh
    horizon-runtime:
      - supervisorctl
      - php

adapter:
  json_critical_commands:
    - site-add
    - site-check
    - services-supported
    - prereq-check
    - doctor
    - project-init
    - deploy-run

versions:
  allow_custom_versions: true
  fallback_policy: stable-lts # stable-lts | nearest-compatible | fail
  php_alias_policy: managed # managed | manual
```

## Notlar

- `port` alanlari istege baglidir; verilmezse engine otomatik atar.
- `mode` tek secimdir; feature flag'ler gecis asamasinda backward-compat icin kalir.
- `prerequisites.policy=fail-fast` oldugunda eksik core paket varsa komut calismaz.
- Runtime komutlari root olmadan calisacak sekilde tasarlanir; root sadece gerekli adimlarda zorunlu tutulur.
- `adapter.json_critical_commands` disindaki komutlarda `--json` zorunlu degildir.
- `horizon.enabled=true` oldugunda `supervisor.enabled=true` ve `supervisorctl` prereq kontrolu zorunludur.
- `versions.allow_custom_versions=true` oldugunda servis bazli custom version secimi aktif olur.
- PHP default alias ve versioned aliaslar (`php82`, `php83` vb.) configten yonetilir.
- `project.type=laravel` oldugunda `laravel.bootstrap/runtime/deploy` adimlari aktif olarak yorumlanir.
- `services.profile=minimal-default` icin default true seti: `nginx(web)`, `php`, `composer`, `mariadb`.
- `services update` cagirildiginda `false -> true` olan servisler algilanir, otomatik kurulur ve baslatilir.
- Tum degiskenler `.env` uzerinden akabilir; mode-ozel degiskenler ilgili prefix ile ayrilir.
- Sonraki asamada JSON Schema/TOML mapping karari alinacak.

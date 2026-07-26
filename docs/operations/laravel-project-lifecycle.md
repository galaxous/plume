# Laravel Project Lifecycle Runbook

Bu runbook, bir Laravel projesinin Plume ile local/prod ortamda en kolay sekilde yonetilmesi icin referanstir.

## 1. Bootstrap

1. `plumectl project init --path=/abs/project`
2. Ihtiyaca gore: `plumectl project init --path=/abs/project --migrate --seed --npm-install --npm-build`
3. Composer install
4. `.env` hazirlama
5. `php artisan key:generate`
6. `php artisan storage:link`
7. Opsiyonel migrate/seed/npm adimlari

## 2. Site Onboarding

1. `plumectl site add` (interactive) veya non-interactive flags
2. `plumectl site list` ile kayıt kontrolü
3. `plumectl site check <site-id>` ile doğrulama
4. `site add --publish` ve gerekirse `site publish` ile webserver snippet, hosts sync ve nginx reload akışları kullanılır.
5. Site bazli PHP runtime secimi `--php-upstream=<host:port|unix:/sock>` ile netlestirilir.
6. Domain planı ve TLS strategy, phase5+ kapsamında genişletilir.

## 3. Runtime Services

1. `plumectl services status` ile desteklenen servis durumu görüntülenir.
2. Native modda `@core`, `@web`, `@db`, `@queue` service group'lari kullanilir.
3. `plumectl services up php --version=<alias|version>` hedef PHP matrix'ini ve extension contract'ini hizli calistirir.
4. `plumectl services up laravel-horizon` native modda supervisor bagimliligini denetler.
5. `plumectl services up phpmyadmin` native modda `PMA_DB_ENGINE` üzerinden engine routing uygular.
6. Queue/Horizon/Scheduler aktivasyonu faz 6+ kapsamı olarak tasarlanmistir ancak native parity akisi artik adapter seviyesinde korunur.
7. `plumectl status`/`site check` ile temel doğrulama yapilir.

## 4. Deploy (Production)

1. Preflight (`prereq check`, `doctor check --deep`)
2. `plumectl deploy plan --mode=...` ile adim listesi
3. `plumectl --yes deploy apply --mode=...` (backup + reconcile + monitor strict)
   - CI veya kisitli ortamda: `--skip-backup`, `--skip-reconcile`, `--skip-health` kombinasyonlari
4. Migration gate (proje icinde `php artisan migrate --force`)
5. Queue/Horizon recycle (`services up horizon` / supervisor)
6. Health gate (`monitor summary --strict`, site `/up`)
7. Sorun halinde `deploy rollback latest` ve gerekirse `deploy failback`
6. Fail olursa rollback (faz 9+)

## 5. Operate

1. `plumectl status`
2. `plumectl status` ile domain/site durumu
3. `plumectl logs <service>` (faz 9+ kapsamı)
4. `plumectl backup create` (opsiyonel config+db)

## 6. Incident Recovery

1. Sorunlu release tespiti
2. `plumectl rollback latest`
3. Health check
4. Incident notu ve karar logu

## Native-First Adapter Notu

- Native mod, laradock-bridge ile ayni komut ailesini kullanacak sekilde tasarlanir.
- Web server secimi `nginx|apache2|caddy` arasindan aktif driver'a gore resolve edilir.
- Her site icin PHP upstream sabitlenebilir; bu, coklu PHP matrix kullanan projelerde en kritik contract'tir.
- DB ve queue servisleri mode'dan bagimsiz olarak ayni nomenclature ile takip edilir, fakat runtime davranis native hizmet yonetimi ile olur.

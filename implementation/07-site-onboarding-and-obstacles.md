# Site Onboarding & Obstacles (Planning)

## Amaç

Herhangi bir website/Laravel projesini sistemde tek komutla web server'a eklemek:

- Path al
- Domain al
- Server sec (nginx/apache2/caddy)
- Config yaz + active et + check et

## Hedef UX

- `plumectl site add`
  - Interaktif prompt ile tum bilgiler alinır
- `plumectl site add --path=/abs/path --domain=myapp.test --server=nginx`
  - CI/otomasyon icin non-interactive

## Registry Modeli

- Site kayitlari Plume'in merkezi dizininde tutulur
- Her site icin ayri dosya: `<site-id>.website.yaml`
- Global indeks: `index.yaml`
- `site-id` deterministik uretilir (`slug + short-hash`)

Ornek site kaydi:

```yaml
id: myapp-a1b2c3
name: myapp
project_path: /Users/dev/Sites/myapp
document_root: /Users/dev/Sites/myapp/public
server: nginx
domains:
  - myapp.test
  - api.myapp.test
mode: native
status: enabled
```

## CWD Karmasasini Engelleme

- Komut hangi klasorden calisirsa calissin registry source-of-truth olur
- Relative path verilirse:
  - `path_policy=absolute-only` ise reddet
  - `path_policy=resolve-relative` ise working dir'e gore absolute'a cevir
- Kayda her zaman absolute path yaz

## Muhtemel Engeller ve Onlemler

1. Path gecersiz veya tasindi
- Engel: registry kaydi stale kalir
- Onlem: `site check` komutu path existence ve web root check yapsin

2. Domain cakismasi
- Engel: ayni domain birden fazla siteye baglanir
- Onlem: `site add` sirasinda domain uniqueness kontrolu + zorunlu override flag

3. Server config drift
- Engel: registry ile nginx/apache/caddy config farkli hale gelir
- Onlem: `site doctor` ile registry->config reconcile raporu

4. Permission/sudo problemi
- Engel: `/etc` veya server config yazimi basarisiz olur
- Onlem: write adimindan once permission preflight + net aksiyon mesaji

5. Farkli server semanticleri
- Engel: nginx/apache2/caddy config yapilari farkli
- Onlem: server bazli template adaptorleri (`sites_nginx`, `sites_apache`, `sites_caddy`)

6. Laravel disi projeler
- Engel: `public/` yoksa varsayim bozulur
- Onlem: promptte custom `document_root` secenegi

## Fazlama

- Faz 1:
  - Registry + `site add/list/remove/check` (native)
  - nginx template
- Faz 2:
  - docker-lite uyumlu site publish
- Faz 3:
  - laradock bridge site sync
- Faz 4+:
  - apache2/caddy template parity

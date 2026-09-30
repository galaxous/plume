# `services web` Commands

## Amac

Native nginx HTTP dinleme portunu **garanti etmek** (varsayilan **80**): macOS Homebrew ve Linux apt/dnf. Plume ana `nginx.conf` listen degerini yonetir, privileged port icin admin onayi alır, site vhost snippet'lerini hizalar. Kullaniciya `brew` / `systemctl` yazdirmaz (D-151).

## Kullanim

```bash
# Tek komut: main conf -> 80, elevated restart, tum native nginx sitelerini republish
plumectl services web ensure

# Onizleme
plumectl services web ensure --dry-run

# Sadece main conf (site republish yok)
plumectl services web ensure --no-republish

# Dusuk seviye (ensure tercih edilir)
plumectl services web sync-config --reload
plumectl services web port 80 --reload
```

Site publish ve `services up|restart web` de otomatik ensure eder (`PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH` / `ENSURE_ON_WEB_UP`, default true).

## Parametreler

### `ensure`

- `--port=<n>`: hedef HTTP port (varsayilan `PLUME_NATIVE_NGINX_HTTP_PORT`, default `80`)
- `--dry-run`: plan
- `--no-republish`: site conf'lari yeniden yazma

### `sync-config` / `port`

- `--port=<n>` / positional port
- `--dry-run`, `--reload`

## Ortam degiskenleri

| Degisken | Default | Anlam |
|----------|---------|--------|
| `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG` | `true` | Ana conf listen yonetimi |
| `PLUME_NATIVE_NGINX_HTTP_PORT` | `80` | Hedef portsuz `http://site.test` |
| `PLUME_NATIVE_NGINX_ENSURE_ON_PUBLISH` | `true` | `site publish` oncesi ensure |
| `PLUME_NATIVE_NGINX_ENSURE_ON_WEB_UP` | `true` | `services up/restart web` oncesi ensure |
| `PLUME_NATIVE_NGINX_MAIN_CONF` | auto | Override path |
| `PLUME_NATIVE_HOMEBREW_HTTP_PORT` | unset | Legacy: zorla 8080 snippet (ensure'i by-pass etmez; manage acikken desired port kazanir — 8080 icin manage=false veya HTTP_PORT=8080) |

## Cikti / Exit code

- `0`: hedef portta veya ensure tamam
- `2`: conf yok, `nginx -t` fail, admin reddi / bind fail

## Ornekler

```bash
# ~/.config/plume/.env (veya defaults)
PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true
PLUME_NATIVE_NGINX_HTTP_PORT=80

plumectl services web ensure
# -> http://myapp.test  (portsuz)
```

8080'de kalmak:

```bash
PLUME_NATIVE_NGINX_HTTP_PORT=8080
plumectl services web ensure --port=8080
```

## Hata senaryolari

- Port **80/443**: Plume sudo ister; reddedilirse ensure fail — tekrar `plumectl services web ensure`.
- Root-owned conf/pid: elevated `nginx -t` / restart.
- Orphan duplicate `server_name` WARN: publish'i bozmaz; conf temizligi ayri.

## Ilgili

- `doctor web` / `doctor web fix-ports`
- `site publish <id> --reload`
- D-151, D-109

# `services web` Commands

## Amac

Native modda Homebrew (veya benzeri) nginx **ana** `nginx.conf` dosyasindaki varsayilan HTTP dinleme portunu yonetmek ve site snippet portlari ile hizalamak.

Homebrew nginx formulü kurulum sirasinda `listen 80` satirini **`listen 8080`** yapar; boylece nginx root/sudo olmadan calisabilir (`homebrew-core` `Formula/n/nginx.rb`, `def install` icindeki `inreplace` ve `caveats`). macOS'ta 1024 alti portlar non-privileged kullaniciya kapali oldugu icin bu bilincli bir varsayilandir.

## Kullanim

```bash
# Ana nginx.conf icindeki varsayilan listen portunu 80 yap (opt-in)
PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true ./plume.sh services web sync-config --reload

# Kisa yol: hedef port arguman
PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true ./plume.sh services web port 80 --reload

# Degisiklik onizlemesi
PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true ./plume.sh services web sync-config --port=80 --dry-run

# Doctor uzerinden ayni islem
PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true ./plume.sh doctor web fix-ports --reload
```

Port 80 sonrasi site vhost'larini guncellemek:

```bash
./plume.sh site publish --reload <site-id>
```

## Parametreler

- `sync-config`
  - `--port=<n>`: hedef HTTP port (varsayilan: `PLUME_NATIVE_NGINX_HTTP_PORT`, default `80`)
  - `--dry-run`: yalnizca mevcut/hedef port ozeti
  - `--reload`: `nginx -t` sonrasi `plume_sites_reload_native nginx` (brew restart veya `nginx -s reload`); basarisizsa `brew services restart nginx` fallback
- `port <n>`: `sync-config --port=<n>` ile ayni; `--dry-run`, `--reload` desteklenir

## Ortam degiskenleri

- `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true|false`: ana `nginx.conf` patch izni (varsayilan `false`)
- `PLUME_NATIVE_NGINX_HTTP_PORT`: hedef HTTP port (varsayilan `80`)
- `PLUME_NATIVE_NGINX_MAIN_CONF`: ana config yolu override (test/dis path icin)
- `PLUME_NATIVE_HOMEBREW_HTTP_PORT`: site render icin zorunlu effective port override (legacy; `8080` tutmak icin)
- `plume_sites_effective_http_port`: once env override, sonra ana config'ten okunan listen, sonra `PLUME_NATIVE_NGINX_HTTP_PORT`

## Cikti / Exit code

- `0`: basarili veya zaten hedef portta
- `2`: izin/env eksik, config bulunamadi, `nginx -t` basarisiz, port 80 icin sudo gerekli

## Ornekler

```bash
# ~/.config/plume/.env
PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG=true
PLUME_NATIVE_NGINX_HTTP_PORT=80

plumectl services web sync-config --reload
plumectl site publish --reload myapp
# http://myapp.test (portsuz)
```

8080'de kalmak (Homebrew varsayilani):

```bash
PLUME_NATIVE_HOMEBREW_HTTP_PORT=8080
# site check url_http -> http://myapp.test:8080
```

## Hata senaryolari

- `PLUME_NATIVE_NGINX_MANAGE_MAIN_CONFIG` kapali: komut fail-fast; once env acin.
- macOS port **80**: `brew services` kullanicisi root olmadan bind edemez; `--reload` sudo yoksa acik hata + `sudo brew services restart nginx` onerisi.
- `--reload` basarisiz (nginx servisi kapali veya reload reddedildi): `brew services restart nginx` (port 80 icin gerekirse `sudo brew services restart nginx`).
- Ana config patch sonrasi site snippet hala `listen 8080;`: `site publish --reload` gerekir (aksi halde default server ile catism riski azalir ama vhost portu eslesmez).
- `nginx -t` basarisiz: yedek `.plume-backup-*` dosyasindan geri yuklenir.

## Ilgili komutlar

- `doctor web`: `listener-80` vs `listener-effective` teshisi; registry port 80 + Homebrew 8080 iken WARN satirinda `services web sync-config --reload` ve `site check` ipuclari (D-109)
- `site check`: `effective_http_port`, `url_http`, `access_hint`

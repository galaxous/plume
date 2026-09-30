# First-Run Onboarding

Bu runbook, Plume'u ilk kez kuran gelistiriciler icin onerilen sirayi ve host profili modelini aciklar.

## Onerilen sira

1. **CLI hazirligi** — [install.md](./install.md): Homebrew (macOS), `install.sh` / Composer / `make install` (Linux).
2. **Global env** — `./plume.sh env init` (veya `--from=templates/native-local.env.example`).
3. **Servis manifest (opsiyonel, önerilir)** — `./plume.sh init host` eksikse `~/.config/plume/services.yml` oluşturur (Laradock benzeri stack tanımı). Greenfield: `./plume.sh init host --apply` veya `./plume.sh services provision --from-manifest`. Ayrıntı: [services-manifest.md](./services-manifest.md).
4. **Host profili** — Adım 3 ile birlikte `./plume.sh init host` yeterli; profil yoksa otomatik bootstrap (`PLUME_AUTO_HOST_BOOTSTRAP=true`).
5. **Onboarding kontrol listesi** —
   ```bash
   ./plume.sh init onboarding
   ```
   macOS'ta Full Disk Access icin once binary listesi: `./plume.sh init permissions`  
   Etkilesimli menu: `./plume.sh init permissions --interactive`  
   System Settings acmak icin: `./plume.sh init permissions --open` (veya `./plume.sh init onboarding --open-settings`)  
   Servisleri baslatmak icin: `./plume.sh init onboarding --fix` (Settings acmaz)
6. **Teshis** —
   ```bash
   ./plume.sh doctor web
   ./plume.sh doctor php
   ```
7. **Shell shim (opsiyonel)** — `./plume.sh init shell`
8. **Servisler** — `./plume.sh services up @core --mode=native`  
   Opsiyonel gelistirme maili (macOS native): `./plume.sh services up mailpit --mode=native` — bkz. [services.md](../commands/services.md) (Mailpit, D-109).
9. **Site** — `./plume.sh site add ... --publish`

## Host profili (`host.env`)

Kalici dosya: `~/.config/plume/host.env`

Neden `host.env` (YAML degil):

- Mevcut Plume state dosyalari (`php.env`, runtime env) ile ayni `key=value` sozlesmesi
- Shell ve adapter tarafinda `grep`/`awk` ile stabil parse

Alanlar: bkz. [init-host.md](../commands/init-host.md)

## macOS ozel notlar

### Full Disk Access (TCC)

Laravel kokunu `~/Desktop`, `~/Documents` veya `~/Downloads` altina koyarsaniz nginx/php-fpm dosyayi okuyamayabilir. Plume bir `.app` degildir; System Settings'te **Plume veya plume.sh eklemeyin**. Bunun yerine:

```bash
./plume.sh init permissions
./plume.sh init permissions --interactive   # TTY menu
```

Detay: [macos-permissions.md](./macos-permissions.md) — gunluk `.env` ve TCC yollari: [local-dev-macos.md](./local-dev-macos.md)

Ciktida listelenen Homebrew **nginx** ve **php-fpm** binary'lerini Full Disk Access'e `+` ile ekleyin. Gerekirse `./plume.sh init permissions --open --reveal`.

Onerilen kok: `~/Sites` veya `~/Code` (FDA cogu zaman gerekmez).

### Nginx port 8080 vs 80

Homebrew nginx varsayilan olarak **8080** dinler (root gerektirmeyen kurulum). Host profili `nginx_http_port_detected` alanina yazar.

Secenekler:

- **8080'de kal** — `PLUME_NATIVE_HOMEBREW_HTTP_PORT=8080`, URL'ler `:8080` ile
- **80'e gec** — `plumectl services web ensure` (bkz. [services-web.md](../commands/services-web.md))

### Homebrew servisler

```bash
brew services start nginx
brew services start php   # veya php@8.3
```

## Linux

Host profili `apt`/`dnf` tespit eder. Nginx/php-fpm icin distro paketleri ve `systemctl` kullanin; onboarding listesi `doctor web` / `doctor php` ile hizalanir.

## Windows

`init host` `os=windows` ve `native_support_note=limited native mode...` yazar. Tam native nginx/site publish bu slice'ta **yok**; WSL2, `docker-lite` veya `laradock-bridge` kullanin.

## Ortam degiskenleri

| Degisken | Varsayilan | Aciklama |
|----------|------------|----------|
| `PLUME_AUTO_HOST_BOOTSTRAP` | `true` | Profil yoksa ilk komutta sessiz tespit |
| `PLUME_HOST_PROFILE_FILE` | `~/.config/plume/host.env` | Profil yolu override |
| `PLUME_NONINTERACTIVE` | `false` | `1` = macOS permission/install promptlarini atla (CI) |
| `PLUME_INTERACTIVE` | (unset) | `1` = prompt zorla; `0` = prompt kapali |

## Ilgili karar

- D-103 — `services.yml` native stack manifest
- D-109 — Native Mailpit (Homebrew) + doctor web port ipuclari
- D-098 — Host profile persistence ve onboarding komutlari
- D-099 — macOS FDA UX: binary listesi, `--fix` vs `--open-settings`

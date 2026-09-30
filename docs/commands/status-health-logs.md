# `status`, `health`, `logs`, `doctor`, `monitor`

## Amac

Sistem sagligini, loglari ve calisma durumunu izlemek.

## Kullanim

```bash
plumectl status --mode=native
plumectl health --mode=laradock-bridge --running
plumectl logs nginx --mode=laradock-bridge --tail=100 --follow
plumectl doctor check
plumectl doctor check --deep
plumectl doctor web --mode=native
plumectl doctor web --mode=native --strict
plumectl doctor web fix-ports --reload
plumectl doctor supervisor [--strict]
plumectl doctor host
plumectl doctor onboarding [--fix] [--open-settings]
plumectl doctor services
plumectl doctor ports
plumectl monitor summary --mode=native
plumectl monitor summary --mode=native --strict
plumectl monitor watch --mode=laradock-bridge --interval=3
plumectl monitor events --mode=native --limit=50
plumectl monitor runbook --mode=laradock-bridge --scenario=incident
```

## Parametreler

- `status|health`: `--mode=...`, `--running`, `--watch[=N]`
- `logs`: `--mode=...`, `--tail=N`, `--follow`, `--running`
- `monitor watch`: `--interval=N`
- `monitor summary`: `--strict` (kritik issue varsa exit code `2`)
- `monitor events`: `--limit=N`
- `monitor runbook`: `--scenario=incident|recovery|ports-conflict`
- `--mode=<native|docker-lite|laradock-bridge>` (`doctor` alt komutlari)
- `--deep` (`doctor check`)
- `--strict` (`doctor web`, `doctor php`, `doctor php-ext`, `monitor summary`)

### `doctor web` (native odak)

Web sunucusu (varsayilan `PLUME_WEB_SERVER_DRIVER`) icin teshis satirlari:

| CHECK | Anlam |
|-------|--------|
| `web-enabled` | `PLUME_WEB_SERVER_ENABLED` acik mi |
| `native-binary` | nginx/apache/caddy binary yolu (native) |
| `init-system` | Homebrew `brew services` veya systemd `active`/`started` |
| `listener-effective` | Registry HTTP portu + `plume_sites_effective_http_port` (orn. 80→8080) uzerinde LISTEN var mi |
| `listener-80` | Port 80 dinleniyor mu (Homebrew varsayilan 8080 iken WARN; `services web sync-config` ile 80 hedeflenebilir) |
| `listener-https` | `PLUME_WEB_HTTPS_PORT` (443) uzerinde dinleyici |
| `strict-includes` | `PLUME_SITE_NGINX_STRICT_ON_RELOAD` ile cache snippet hedef include'da ve eslesiyor mu |
| `sites-port80` | Registry'de `port: 80` site sayisi vs gercek port 80 dinleyicisi |
| `macos-site-tcc` | (macOS) Site path `Desktop`/`Documents`/`Downloads` altinda mi — WARN + `init permissions --interactive` ipucu |

`OVERALL FAIL` + `--strict` → exit code `2` (kritik satirlarda FAIL).

## Cikti / Exit Codes

- `0`: saglikli/rapor basarili
- `1`: genel hata
- `2`: kritik sorun tespit edildi

## Ornekler

```bash
plumectl status --mode=native --watch=2
plumectl doctor check --mode=native --deep
plumectl doctor web --mode=native --strict
plumectl doctor services --mode=laradock-bridge
plumectl doctor ports --mode=docker-lite
plumectl monitor events --mode=laradock-bridge --limit=20
plumectl monitor runbook --mode=native --scenario=recovery
```

## Hata Senaryolari

- Log kaynagi okunamiyor
- Health-check komutlari yok
- State/registry bozuk
- `monitor events` icin `sqlite3` yok

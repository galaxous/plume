# Project-local `plume.yml` (Phase 16 MVP)

Proje kokundeki `plume.yml`, site onboarding ve CLI cozumlemesi icin **dar bir MVP** alan seti okur. Tam taslak: [implementation/03-config-yaml-draft.md](../../implementation/03-config-yaml-draft.md). Karar: [implementation/05-decision-log.md](../../implementation/05-decision-log.md) (D-117).

## MVP alanlari

```yaml
version: 2          # opsiyonel; dokumantasyon amacli
project:
  mode: native      # native | docker-lite | laradock-bridge
  php_version: "8.3"
  type: laravel     # laravel | generic-php | static (opsiyonel)
mode: native        # phase-4 geriye uyum; project.mode onceliklidir
```

Dosya adi varsayilan `plume.yml`; override: `PLUME_CONFIG_FILE` (proje kokune gore relative veya mutlak yol).

## Merge / oncelik kurallari

| Alan | Proje `plume.yml` | Kullanici `services.yml` | `~/.config/plume/.env` | CLI / registry |
|------|-------------------|--------------------------|-------------------------|----------------|
| `project.mode` | Cozumleme hint | — | `PLUME_MODE` (global) | `--mode` kazanir; kayitli site `mode` site operasyonunda authoritative |
| `project.php_version` | `site add` hint | — | `PLUME_PHP_*` kurulu surum listesi | `--php` / `--php-version` kazanir |
| Servis enable | MVP disi (stretch) | Evet (D-103) | Evet (manifest uzerinde) | `services` komutlari |
| Domain / path | MVP disi | — | — | Site registry + `site add/update` |

Registry (`PLUME_SITE_REGISTRY_DIR` veya `~/.config/plume/sites`) ile otomatik iki yon sync **yok**; manifest yalnizca okuma/hint katmanidir.

## Komutlar

- `plumectl project config show --path=/abs/project` — yuklenen MVP alanlarini yazar.
- `plumectl site add` — `--mode` yoksa manifest mode; `--php` yoksa `project.php_version` (validation sonrasi).

## Smoke

Hermetik test: `tests/phase16_plume_yml_v2_smoke.sh` (`HOME`, `PLUME_STATE_DIR`, `PLUME_SITE_REGISTRY_DIR` gecici).

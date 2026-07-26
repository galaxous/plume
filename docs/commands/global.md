# Global Commands

## Amac

Tum komutlarda ortak davranislarin tanimi.

## Kullanim

```bash
./plume.sh --help
./plume.sh --version
./plume.sh --json services supported
./plume.sh --quiet services update
./plume.sh --env-file /path/to/custom.env services status
```

## Parametreler

- `--help`, `-h`: yardim metni
- `--version`, `-v`: surum bilgisi
- `--json`: desteklenen komutlarda JSON cikti
- `--yes`: non-interactive onay modu (phase2 baseline); macOS permission/brew promptlarini da atlar
- `--quiet`: info loglarini susturur
- `--env-file <path>`: default `.env` yerine o dosyayi yukler

macOS permission menu ve host install onaylari icin ayrica `PLUME_NONINTERACTIVE=1` kullanilabilir (bkz. `docs/operations/macos-permissions.md`).

## Notlar

- `--env-file` verilmezse plume global env dosyasini yukler:
  - `~/.config/plume/.env` (veya `PLUME_GLOBAL_ENV_FILE`)
- Global env yoksa ve example varsa otomatik bootstrap edilir:
  - once `~/.config/plume/.env.example`
  - sonra plume built-in example (`templates/native-core.env.example`)
  - yoksa calisma dizinindeki `.env.example`
- Preset kullanimi icin `env init --from=...` onerilir:
  - local: `templates/native-local.env.example` (extension auto-sync `matrix`)
  - prod: `templates/native-prod.env.example` (extension auto-sync `target`)
- Komut calistirirken disaridan verilen `PLUME_*` / `PMA_*` env degerleri global env tarafindan override edilmez (CLI/env oneceliklidir).

## Cikti / Exit Codes

- `0`: basarili
- `1`: genel/runtime hata
- `2`: validation/prereq/user-correctable hata

## Ornekler

```bash
./plume.sh --json services status
./plume.sh --env-file /tmp/plume.env prereq check
```

## Hata Senaryolari

- Bilinmeyen komut
- `--env-file` verilip path verilmemesi
- Verilen `--env-file` dosyasinin bulunamamasi

## Naming Notu

- Resmi binary: `plumectl`
- Test asamasi calistirma: `./plume.sh`
- Opsiyonel alias: `plume`

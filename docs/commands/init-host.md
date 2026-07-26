# `init host` Command

## Amac

Ilk kurulumda (ve gerektiginde) makine kimligini tespit edip `~/.config/plume/host.env` dosyasina yazmak. Adapter ve doktor komutlari bu dosyayi parse edebilir.

## Kullanim

```bash
./plume.sh init host
./plume.sh init host --force
./plume.sh init host --json
./plume.sh init host --apply
./plume.sh doctor host
./plume.sh doctor host --force
```

Eksikse `templates/services.yml.example` → `~/.config/plume/services.yml` kopyalanir (mevcut dosya korunur). Bkz. [services-manifest.md](../operations/services-manifest.md).

## Parametreler

- `--force`: mevcut profili yeniden tespit edip uzerine yazar
- `--json`: ciktiyi tek satir JSON olarak verir (dosya icerigi alanlari)
- `--apply`: manifest'e gore native host kurulumu (`services provision --from-manifest` ile ayni)

## Dosya formati

Yol: `~/.config/plume/host.env` (override: `PLUME_HOST_PROFILE_FILE`)

Alanlar (key=value):

| Alan | Aciklama |
|------|----------|
| `os` | `macos`, `linux`, `windows`, `unknown` |
| `os_version` | macOS productVersion veya linux VERSION_ID |
| `arch` | `uname -m` |
| `package_manager` | `brew`, `apt`, `dnf`, `manual`, `missing` |
| `web_driver_hint` | Aktif `PLUME_WEB_SERVER_DRIVER` (varsayilan nginx) |
| `nginx_http_port_detected` | Ana nginx.conf listen portu (bos = bulunamadi) |
| `homebrew_nginx` | `true` / `false` |
| `state_dir` | `PLUME_STATE_DIR` anlik degeri |
| `detected_at` | UTC ISO8601 |
| `native_support_note` | Yalnizca Windows: sinirli native mod notu |

## Cikti / Exit code

- `0`: basarili veya profil zaten var (--force yok)
- `2`: yazma/option hatasi

## Ornekler

```bash
./plume.sh init host
grep nginx_http_port_detected ~/.config/plume/host.env
```

## Otomatik bootstrap

`PLUME_AUTO_HOST_BOOTSTRAP=true` (varsayilan) iken profil yoksa ilk `plume.sh`/`plumectl` cagrisinda sessizce `init host` calisir. Kapatmak icin:

```bash
export PLUME_AUTO_HOST_BOOTSTRAP=false
```

## Hata senaryolari

- `$HOME/.config/plume` yazilamaz: exit 2
- Windows/Git Bash: `os=windows` ve `native_support_note` set edilir; tam native nginx kurulmaz

## Ilgili

- `docs/operations/first-run-onboarding.md`
- `init onboarding`, `doctor web`, `services web sync-config`

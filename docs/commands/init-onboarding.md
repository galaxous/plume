# `init onboarding` Command

## Amac

Ilk calistirmada kullanicinin TCC, nginx 8080, proje yolu ve php-fpm servislerini tek tek kesfetmesini onlemek icin kontrol listesi basmak. macOS'ta Full Disk Access icin **eklenecek nginx/php-fpm binary yollarini** net listeler (Plume veya `plume.sh` degil).

## Kullanim

```bash
./plume.sh init onboarding
./plume.sh init onboarding --fix
./plume.sh init onboarding --open-settings
./plume.sh doctor onboarding
./plume.sh doctor onboarding --fix
```

## Parametreler

- `--fix`: Guvenli host duzeltmeleri (macOS + Homebrew: `brew services start nginx` ve kurulu PHP formulune gore php/php@X). **System Settings acmaz.**
- `--open-settings` (macOS): Full Disk Access gizlilik bolumunu acmayi dener; once binary listesi basilir. Basarisizsa exit `2`.

## Cikti / Exit code

- `0`: bilgilendirme tamamlandi
- `2`: bilinmeyen flag veya `--open-settings` ile Settings acilamadi

## Kontrol listesi (ozet)

| OS | Maddeler |
|----|----------|
| macOS | Dev/repo notu, TCC / Desktop-Documents uyarisi, `~/Sites` veya `~/Code`, nginx 80 vs 8080, FDA icin nginx/php-fpm yollari, `brew services` ipuclari |
| linux | Proje yolu, nginx port, systemctl ipuclari |
| windows | Sinirli native mod; WSL2/docker-lite onerisi |

Repo kokunden `./plume.sh` ile calisiyorsaniz cikti **Dev / repo checkout** satirini vurgular; FDA cogu zaman opsiyoneldir (Desktop disi path).

Host profili yoksa onboarding once `init host` tespitini calistirir.

## Ornekler

```bash
./plume.sh env init
./plume.sh init onboarding
./plume.sh init onboarding --fix              # brew nginx/php baslat
./plume.sh init permissions --open            # FDA pane + binary listesi
./plume.sh init permissions --open --reveal   # + Finder'da nginx bin dizini
```

## Hata senaryolari

- `--fix` / `--open-settings` macOS disinda: liste yine basilir; macOS-only flag'ler bilgi satiri ile aciklanir
- `--open-settings` deep link desteklenmeyen macOS: exit `2`, manuel GUI adimlari icin `init permissions` ciktisindaki yollar kullanilir

## Ilgili

- `init permissions`, `doctor web` (`macos-site-tcc`), `docs/commands/services-web.md`
- `docs/operations/first-run-onboarding.md`
- Karar: D-099

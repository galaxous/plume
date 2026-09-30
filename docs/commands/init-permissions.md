# `init permissions` Command

## Amac

macOS native modda nginx/php-fpm ve proje dosyalarina erisim icin kullanicinin hangi izinleri vermesi gerektigini listelemek; istege bagli System Settings acmak. Plume bir CLI betigidir — listede **Plume uygulamasi veya `plume.sh` yoktur**; Full Disk Access'e Homebrew **nginx** ve **php-fpm** binary'leri eklenir.

## Kullanim

```bash
./plume.sh init permissions
./plume.sh init permissions --open
./plume.sh init permissions --reveal
./plume.sh init permissions --open --reveal
./plume.sh init permissions --interactive
```

## Parametreler

- `--open`: Once nginx/php-fpm yollarini basar, uyari verir, sonra Full Disk Access gizlilik bolumunu acmayi dener (`open x-apple.systempreferences:...`)
- `--reveal`: Finder'da nginx binary dizinini acar (Homebrew `.../opt/nginx/bin` veya `command -v nginx` dizini)
- `--interactive`: TCC riski varsa (kayitli siteler Desktop/Documents/Downloads altinda) tty uzerinden menu: FDA ac, ~/Sites tasima onerisi, devam et, iptal. Bu bayrak `PLUME_INTERACTIVE=true` zorlar (IDE terminalinde `-t` algisi basarisiz olsa bile).

## Cikti / Exit code

- `0`: basarili (macOS disinda bilgi mesaji ile)
- `2`: `--open` veya `--reveal` basarisiz

Cikti her zaman su uyariyi icerir:

```text
Plume is a CLI script — do NOT add plume.sh or a "Plume" app in Full Disk Access.
```

Ardindan cozulmus `nginx` ve `php-fpm` yollari (`command -v`, `brew --prefix`) listelenir; istege bagli Terminal/iTerm yolu.

## Ornekler

```bash
./plume.sh init permissions
./plume.sh init permissions --open
./plume.sh doctor web    # macos-site-tcc satiri
./plume.sh doctor php    # MACOS_TCC satiri
```

## Hata senaryolari

- linux/windows: komut bilgilendirme verir, grant listesi macOS'a ozgudur
- `--open` GUI oturumu yok (SSH headless): manuel adimlar gerekir; ciktideki binary yollarini kullanin
- Binary bulunamazsa placeholder ipuclari basilir (nginx/php kurulumu eksik)

## Ilgili

- `docs/operations/macos-permissions.md` (otomasyon vs manuel FDA)
- `docs/commands/site.md` (TCC troubleshooting)
- `init onboarding`, D-099, D-100

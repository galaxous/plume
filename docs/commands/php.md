# `php` Commands

## Amac

Birden fazla PHP surumunu yonetmek, default `php` alias'ini degistirmek ve surum bazli aliaslari kullanmak.

## Kullanim

```bash
plumectl php list
plumectl php install 8.3
plumectl php use 8.3
plumectl php alias list
plumectl php alias set php83 8.3
plumectl php alias default 8.3
plumectl php ext sync all
plumectl php ext sync 8.4
plumectl php ext doctor --strict
plumectl php ext resolve all
plumectl php ext resolve 8.4
plumectl php shim install
eval "$(plumectl php shim env)"
php8.4 -v
php-fpm-8.4 -v
plumectl doctor php
plumectl doctor php --strict
```

## Parametreler

- `install <version>`
- `use <version>` (aktif/default surumu degistirir)
- `alias set <name> <version>`
- `alias default <version>`
- `ext sync <version|all> [--strict|--no-strict]`
- `ext doctor [--strict]`
- `ext resolve <version|all>`
- `shim install|env|list|remove`

Native mode davranisi:

- `php install <version>`:
  - surumu `PLUME_PHP_INSTALLED_VERSIONS` listesine ekler
  - otomatik canonical alias olusturur (`8.4 -> php84`)
- `php use <version|alias>`:
  - `PLUME_PHP_DEFAULT_VERSION` ve `PLUME_PHP_VERSION` degerlerini gunceller
  - secilen surum listede yoksa otomatik ekler
- Konfigurasyon kalici olarak `~/.config/plume/state/php.env` (veya `PLUME_STATE_DIR/php.env`) dosyasina yazilir.
- `php shim install`:
  - `PLUME_PHP_INSTALLED_VERSIONS` listesinden host shim dosyalari olusturur
  - ornek: `php8.4`, `php84`, `php-fpm-8.4`, `php-fpm84`
  - varsayilan dizin: `~/.config/plume/shims`
- `php shim env`:
  - shim dizinini `PATH`'e eklemek icin export satiri basar
  - ayrica default disi tum kurulu surumler icin shell aliaslari basar:
    - `php81 -> php8.1`
    - `phpfpm81 -> php-fpm-8.1`
  - default `php` binary degismez; sadece `php8.4` gibi hedef komutlar aktif olur

Extension contract (hybrid: preset + toggle + matrix):

- Preset katmani:
  - `PLUME_PHP_EXT_PRESET=none|laravel-core|queue|media|full`
  - opsiyonel surum bazli preset override: `PLUME_PHP_EXT_PRESET_81`, `..._84`
- Matrix katmani:
  - `PLUME_PHP_EXTENSIONS_GLOBAL` tum surumlere uygulanir.
  - `PLUME_PHP_EXTENSIONS_81`, `PLUME_PHP_EXTENSIONS_82`, ... surum-bazli ek extension seti tanimlar.
- Toggle katmani:
  - global enable: `PLUME_PHP_EXT_ENABLE_REDIS=true`
  - surum bazli enable: `PLUME_PHP_EXT_ENABLE_84_XDEBUG=true`
  - surum bazli disable: `PLUME_PHP_EXT_DISABLE_84_IMAGICK=true`
- Cozumleme sirasi:
  - `preset + matrix + enable toggles - disable toggles`
  - disable toggle her zaman son soz sahibidir.
- `php ext resolve` ilgili surum(ler) icin nihai extension listesini gosterir.
- `php ext sync` ilgili surum(ler)de eksik extensionlari kurmayi dener ve verify eder.
- `PLUME_PHP_EXTENSIONS_STRICT=true` ise verify edilemeyen extension oldugunda komut `exit 2` doner.
- `services up php` sirasinda otomatik sync kapsamini `PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=matrix|target|default` belirler.

## Cikti / Exit Codes

- `0`: basarili
- `2`: validation/prereq/supported-version hatasi

## Ornekler

```bash
plumectl php install 8.2
plumectl php use 8.2
plumectl php alias set php82 8.2
plumectl services up php --mode=native
plumectl services up php --mode=native --version=php82
plumectl php shim install
eval "$(plumectl php shim env)"
php8.4 -v
php-fpm-8.4 -v
```

## Hata Senaryolari

- Desteklenmeyen PHP surumu
- Alias adi cakismasi
- Default alias degisimi icin gerekli izin yok
- Host'ta hedef surum binary'si bulunamiyor (`doctor php --strict` ile fail-fast kontrol edilebilir)

## Phase 6 Notu

- `services install php --version=<alias|version>` ve `services up php --version=<alias|version>` komutlari:
  - `php`, `default`, `php83` gibi aliaslari `PLUME_PHP_DEFAULT_VERSION` / `PLUME_PHP_ALIAS_*` ile cozumler.
  - Cozumlenen surum `PLUME_PHP_INSTALLED_VERSIONS` listesinde yoksa komut `exit 2` ile fail olur.
- Native host binary provisioning:
  - `services install php --mode=native --version=<x.y>` komutu, hostta CLI/FPM binary kurulumunu dener ve dogrular.
  - Basariliysa ilgili surumu php matrix state'ine (`php.env`) otomatik ekler.
- Native FPM servis baslatma (`services up php82`, `--version=8.2`): macOS'ta `brew services start php@x.y`; baslatmadan once pool `listen` canonical unix socket (`/opt/homebrew/var/run/php@x.y-fpm.sock`) ile hizalanir (D-107); bkz. [services.md](./services.md).

# `composer` / `npm` / `node` (workspace)

## Amac

Herd benzeri Composer ve Node gelistirme yuzeyi: proje kokunde host (native) veya `workspace` container (docker-lite / laradock-bridge) uzerinden arac calistirir (D-154 / Faz 27).

## Kullanim

```bash
plumectl composer install
plumectl composer --path=/var/www/app require laravel/horizon
plumectl composer --site=site-xxx update
plumectl npm install
plumectl npm run build
plumectl npm --path=/var/www/app run dev
plumectl node -v
plumectl composer --mode=docker-lite install
```

## Parametreler

| Bayrak | Aciklama |
|--------|----------|
| `--path=` | Proje kok (composer.json / package.json / artisan) |
| `--site=` | Kayitli site yolu (+ composer icin site `php_version`) |
| `--mode=` | `native` (varsayilan aktif mode) / `docker-lite` / `laradock-bridge` |
| `--` | Sonrasi arac bayraklari (opsiyonel ayirici) |

Arac argumanlari Plume bayraklarindan sonra dogrudan `composer` / `npm` / `node`e gider. Arguman yoksa surum bayragi (`-V` / `-v`) kullanilir.

Not: plumectl global `--version` / `-v` surum gosterir; arac surumu icin `composer -V`, `npm -- -v`, `node -- -p process.version` veya `tool -- --version`.

## Davranis

### native

- Proje yolu: `--path` → `--site` → cwd site eslesmesi → cwd (`composer.json`/`package.json`/`artisan`) → mode path
- **npm:** cwd veya mode path'te `package.json` veya `artisan` yoksa hata (bos dizinde ENOENT yok)
- **composer:** `composer.json` veya `artisan` gerekir
- **node:** proje isaretleri yoksa cwd'ye duser (one-liner / `-p`); npm gibi katı degil
- Composer: site/default PHP `PATH` basina eklenir (`COMPOSER_PHP` mumkunse); `PLUME_COMPOSER_BIN` (varsayilan `composer`)
- npm/node: `PLUME_NPM_BIN` / `PLUME_NODE_BIN` (varsayilan `npm` / `node`)

### docker-lite / laradock-bridge

- `workspace` (composer alias) container icinde `composer|npm|node` exec (`-T`)
- Compose dosyasi mode path / workspace init gerektirir

## Cikti / exit-code

- `0`: arac basarili (veya `--help`)
- `2`: path cozulemedi, binary yok, compose yok, bilinmeyen mode/bayrak
- Arac kendi exit kodunu dondurur (basarisiz install vb.)

## Ornekler

```bash
cd ~/Sites/tunnelion
plumectl composer install --no-interaction
plumectl npm ci
plumectl npm run build
```

## Hata senaryolari

- `could not resolve project path` — `--path=` / `--site=` / proje kokunden calistir (`npm` icin `package.json` veya `artisan` gerekir)
- `composer not found` — host Composer veya `PLUME_COMPOSER_BIN`
- `npm not found` / `node not found` — Node.js veya `PLUME_NPM_BIN` / `PLUME_NODE_BIN`
- `compose file not found` — docker mode: `services workspace init` / mode path

Iliskili: [project.md](./project.md) (`project init` bootstrap), [php.md](./php.md) (PHP matrix).

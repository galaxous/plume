# `project` Komutu

## Amac

`plumectl project` ailesi, Laravel proje bootstrap ve `.env` secret senkron adimlarini tek yuzeyde toplar.

## Kullanim

```bash
plumectl project init --path=/abs/project
plumectl project config show --path=/abs/project
plumectl project init --path=/abs/project --migrate --seed --npm-install --npm-build
plumectl project init --path=/abs/project --dry-run
plumectl project env sync-secrets --path=/abs/project --keys=APP_KEY,DB_PASSWORD
```

## Parametreler

- `--path=<abs_path>`: zorunlu proje yolu
- `--dry-run`: adimlari sadece plan olarak yazdirir, dosya/komut degisikligi yapmaz
- `--migrate`: `php artisan migrate --force`
- `--seed`: `php artisan db:seed --force` (otomatik olarak `--migrate` de calisir)
- `--npm-install`: `npm install`
- `--npm-build`: `npm run build`
- `--npm-dev`: `npm run dev`
- `--skip-composer`: `composer install` adimini atlar
- `--skip-key-generate`: `php artisan key:generate` adimini atlar
- `--skip-storage-link`: `php artisan storage:link` adimini atlar
- `project env sync-secrets`:
  - `--path=<abs_path>`: zorunlu proje yolu
  - `--keys=K1,K2`: opsiyonel key filtresi (verilmezse tum secret keyleri)
  - `--dry-run`: yazmadan planlanan `.env` degisimlerini gosterir
  - `--create-env`: `.env` yoksa `.env.example` uzerinden olusturur

## Davranis

1. `composer.json` varsa `composer install`
2. `.env` yoksa `.env.example` dosyasindan `.env` olusturur
3. `artisan` varsa:
   - `key:generate`
   - `storage:link`
   - opsiyonel `migrate` / `db:seed`
4. `package.json` varsa opsiyonel npm adimlari
5. `project env sync-secrets`, state'deki `secrets.env` keylerini proje `.env` dosyasina yazar/gunceller
6. `project config show`, proje `plume.yml` MVP alanlarini okur — ayrinti: [project-config.md](project-config.md)

## Alt komutlar

| Alt komut | Dokuman |
|-----------|---------|
| `init` | bu dosya |
| `config show` | [project-config.md](project-config.md) |
| `env sync-secrets` | bu dosya |

## Exit Kodlari

- `0`: basarili
- `2`: girdi/validation hatasi veya adim komutu hatasi

## Ornekler

```bash
plumectl project init --path=/var/www/myapp
plumectl project init --path=/var/www/myapp --migrate --seed
plumectl project init --path=/var/www/myapp --skip-composer --dry-run
plumectl project env sync-secrets --path=/var/www/myapp --keys=APP_KEY,DB_PASSWORD
```

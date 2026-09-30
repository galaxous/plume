# `composer` Command

## Amac

Proje dizininde Composer calistirir (site PHP tercih edilir). Detay: [workspace.md](./workspace.md) (D-154).

## Kullanim

```bash
plumectl composer install
plumectl composer --path=/abs/app require laravel/horizon --no-interaction
plumectl composer --site=site-xxx update
```

## Parametreler

`--path=`, `--site=`, `--mode=` — bkz. [workspace.md](./workspace.md).

## Cikti / exit-code

Composer exit kodu; Plume hata `2`.

## Ornekler

```bash
plumectl composer --version
plumectl composer install --no-dev
```

## Hata senaryolari

- `composer not found` — host Composer veya `PLUME_COMPOSER_BIN`
- `could not resolve project path` — `--path=` / proje kok

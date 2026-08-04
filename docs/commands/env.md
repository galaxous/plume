# `env` Commands

## Amac

Plume'in sistem seviyesindeki global env dosyasini yonetmek.

## Kullanim

```bash
./plume.sh env where
./plume.sh env init
./plume.sh env init --force
./plume.sh env init --from=/abs/path/to/.env.example
./plume.sh env set PLUME_REDIS_PASSWORD=mysecret
```

## Parametreler

- `where`
  - global env, global example ve built-in example dosya yollarini gosterir.
- `init`
  - global env dosyasini initialize eder.
  - varsayilan kaynak sirasi:
    - `~/.config/plume/.env.example`
    - plume built-in: `templates/native-core.env.example`
    - calisma dizinindeki `.env.example`
  - preset kaynaklari:
    - local: `templates/native-local.env.example` (`PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=target`)
    - prod: `templates/native-prod.env.example` (`PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=target`)
  - `--from=...` ile ozel kaynak verilebilir.
  - `--force` ile mevcut global env overwrite edilir.
- `set KEY=VALUE`
  - `~/.config/plume/.env` icinde `PLUME_*` anahtarini gunceller veya ekler.
  - Stack servis anahtarlari icin etkilenen servisler icin restart onerisi yazilir.

## Cikti / Exit Codes

- `0`: basarili
- `2`: validation hatasi (ornek dosya yok, gecersiz option, `PLUME_*` disi anahtar)

## Ornekler

```bash
./plume.sh env where
./plume.sh env init
./plume.sh env init --force
./plume.sh env init --from=/path/to/plume/templates/native-local.env.example --force
./plume.sh env set PLUME_MONGODB_PASSWORD=example
./plume.sh services restart mongodb --mode=native
```

Stack servis kisa yolu: [services-env.md](services-env.md).

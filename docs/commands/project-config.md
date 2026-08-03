# `project config` Komutu

## Amac

Proje kokundeki `plume.yml` dosyasindan Phase 16 MVP alanlarini okuyup insan-okunur cikti vermek (`project.mode`, `project.php_version`, `project.type`).

## Kullanim

```bash
plumectl project config show --path=/abs/project
```

## Parametreler

- `--path=<abs_path>`: zorunlu; proje dizini (icinde `plume.yml` veya `PLUME_CONFIG_FILE` hedefi)

## Cikti / exit-code

- Cikti: `key=value` satirlari (`manifest=`, `schema_version=`, `mode=`, `php_version=`, `project_type=` — bos alanlar atlanir)
- `0`: basarili okuma
- `2`: path/manifest yok, gecersiz `project.type` veya gecersiz mode

## Ornekler

```bash
./plume.sh project config show --path=/var/www/myapp
```

Ornek cikti:

```text
manifest=/var/www/myapp/plume.yml
schema_version=2
mode=docker-lite
php_version=8.2
project_type=laravel
```

## Hata senaryolari

- `--path` verilmedi veya dizin yok
- `plume.yml` bulunamadi
- `project.type` veya `mode` gecersiz deger

Merge kurallari: [docs/operations/project-plume-yml.md](../operations/project-plume-yml.md).

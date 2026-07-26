# `prereq` Commands

## Amac

Core bagimliliklari profile bazli fail-fast kontrol etmek.

## Kullanim

```bash
./plume.sh prereq check
./plume.sh prereq check --profile=base
./plume.sh prereq check --profile=native-install
./plume.sh prereq explain
./plume.sh --json prereq check --profile=git-ops
```

## Parametreler

- `check`: profile bazli prereq kontrolu
  - `--profile=base|native-install|git-ops|docker-lite|security-check|horizon-runtime|laravel-bootstrap|frontend-build`
- `explain`: tum profilleri ve gerekcelerini listeler

## Cikti / Exit Codes

- `0`: tum zorunlu bagimliliklar mevcut
- `2`: eksik bagimlilik veya gecersiz kullanim

## Ornekler

```bash
./plume.sh prereq check --profile=base
./plume.sh prereq check --profile=native-install
./plume.sh --json prereq check --profile=docker-lite
./plume.sh prereq explain
```

## Hata Senaryolari

- Bilinmeyen profil
- Eksik core komut/paket (`brew/apt/dnf` dahil)
- Gecersiz flag kullanimi

## Notlar

- macOS'ta package manager kontrolu `brew` uzerinden yapilir.
- Linux'ta package manager kontrolu `apt` veya `dnf` uzerinden yapilir.
- Service install/update gibi kurulum komutlari root/sudo gerektirir.

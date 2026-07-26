# `mode` Commands

## Amac

Calisma modunu degistirmek ve dogrulamak.

## Kullanim

```bash
./plume.sh mode use native
./plume.sh mode use native --force --yes --down-running
./plume.sh mode use docker-lite
./plume.sh mode use laradock-bridge
./plume.sh mode current
./plume.sh mode path set /abs/project
./plume.sh mode path get
./plume.sh mode path clear
./plume.sh mode path set docker-lite /abs/project
./plume.sh mode path get docker-lite
./plume.sh mode path list
./plume.sh mode path clear docker-lite
```

## Parametreler

- `use <mode> [--force] [--down-running]`
- `current`
- `path set [docker-lite|laradock-bridge] <path> [--force]`
- `path get [docker-lite|laradock-bridge]`
- `path clear [docker-lite|laradock-bridge]`
- `path list`

Not:

- `path` komutlarinda mode verilmezse aktif mode (`mode current`) kullanilir.

Oncelik sirasi (deterministic):

- `mode`: `--mode` > `mode use` ile kaydedilen global state > `native`
- docker-lite compose/path: `--path` > `mode path` > workspace remembered compose > current working directory compose
- laradock-bridge path: `--path` > `mode path`
- laradock-bridge compose: `PLUME_LARADOCK_COMPOSE_FILE` > `<mode-path>/docker-compose.yml|compose.yml`
- `.env` dosyasi `mode/path` degerlerini override etmez.

Laradock guvenlik kurali:

- `laradock-bridge` runtime komutlari path tahmin etmez.
- `mode path set laradock-bridge <path>` yapilmamis ve `--path` gecilmemisse komut fail eder.
- Boylece plume hangi Laradock dizinine dokunacagini deterministic sekilde bilir.

Lock davranisi:

- Kurulum/servis baslatma sonrasinda global context lock aktif olur.
- Lock stale ise (canli workload yoksa) lock otomatik temizlenir.
- Lock aktifken `mode use` ve `mode path set/clear` komutlari `--force` olmadan degisiklik yapmaz.
- Aktif `docker-lite` path'te container calisiyorsa `mode/path` degisikligi `--force` ile bile yapilmaz.
- Bu durumda once `./plume.sh services workspace down --mode=docker-lite` calistirilmalidir.
- Aktif `laradock-bridge` konteynerleri varken `mode use native` gecisi bloklanir.
  - Otomatik kapatma icin:
    - `./plume.sh mode use native --force --yes --down-running`
  - Manual kapatma alternatifi:
    - `cd <laradock-path> && docker compose down`
- `docker-lite` path degisimi (`mode path set ... --force`) sirasinda:
  - eski path'te calisan container varsa degisim engellenir,
  - yeni path'te compose dosyasi yoksa komut warning verir (`services workspace init` onerilir).

## Cikti / Exit Codes

- `0`: mod degisimi basarili
- `2`: gecersiz mod

## Ornekler

```bash
./plume.sh mode use native
./plume.sh mode current
```

## Hata Senaryolari

- Gecersiz mode degeri
- Prereq saglanmayan moda gecis denemesi
- Gecersiz veya olmayan path ile `mode path set`

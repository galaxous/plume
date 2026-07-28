# `schedule` Commands

## Amac

Laravel zamanlayici operasyonlari: durum ozeti (`status`), kayitli gorev listesi (`list`), tek seferlik `schedule:run` (`run-once`), kullanici crontab satiri ekleme/kaldirma (`cron-install`).

## Kullanim

```bash
./plume.sh schedule status
./plume.sh schedule status --mode=native
./plume.sh schedule status --path=/abs/laravel-app
./plume.sh --json schedule status --path=/abs/laravel-app

./plume.sh schedule list --path=/abs/laravel-app
./plume.sh schedule run-once --path=/abs/laravel-app
./plume.sh schedule run-once --path=/abs/laravel-app --dry-run

./plume.sh schedule cron-install --path=/abs/laravel-app
./plume.sh schedule cron-install --path=/abs/laravel-app --dry-run
./plume.sh schedule cron-install --path=/abs/laravel-app --remove
```

## Parametreler

- `status` (varsayilan alt komut): Scheduler durumu.
- `list`: Proje dizininde `php artisan schedule:list` calistirir (Laravel 8+); cikti Artisan'a aittir.
- `run-once`: Proje dizininde `php artisan schedule:run --no-interaction` bir kez calistirir.
- `cron-install`: Kullanicinin crontab'ina (root degil) tek satir ekler veya `--remove` ile kaldirilir. Satir sonunda `# plume-laravel-schedule-cron` marker vardir.
- `--dry-run` (`run-once`, `cron-install`): Komutu/crontab yazimini calistirmaz; planlanan shell veya crontab satirini yazar.
- `--remove` (`cron-install`): Marker iceren plume scheduler satirlarini crontab'dan siler.
- `--mode=native|docker-lite|laradock-bridge`: `status` icin mod baglami (diger alt komutlarda yok sayilir).
- `--path=/abs/project`: Laravel proje kokunu zorla; verilmezse kayitli site (CWD eslesmesi), CWD'de `artisan`, veya aktif mod workspace yolu denenir.
- Global `--json`: Yalnizca `status` icin JSON cikti (`ok`, `command`, `data`).
- Test/smoke: `PLUME_CRONTAB_FILE=/path/to/file` ile gercek `crontab` yerine dosya kullanilir (hermetik testler).

## Cikti / Exit Codes

- `0`: Basarili (`status`, `list`, `run-once`, `cron-install`, `--dry-run`, `--remove`, zaten kurulu idempotent).
- `1`: Artisan komutu basarisiz (`list`, `run-once`; Laravel cikis kodu iletilir).
- `2`: Gecersiz arguman, proje yolu cozulemedi, `artisan` yok, `php` bulunamadi, root kullanici, veya `crontab` yok.

Text `status` ciktisi: `MODE`, `PROJECT_PATH`, `PROJECT_SOURCE`, `ARTISAN` (`present|missing`), `SCHEDULER_CRON` (`configured|maybe|not-configured|unknown`), `CRON_HINT`.

`cron-install` satiri (ornek): `* * * * * cd /abs/project && /path/to/php artisan schedule:run >> /dev/null 2>&1 # plume-laravel-schedule-cron` — PHP yolu site surumu veya `PLUME_PHP_BIN` ile cozulur.

`run-once`: Crontab yoksa (`not-configured`) basarili calismadan sonra INFO ile `cron-install` veya `CRON_HINT` hatirlatilir.

## Ornekler

```bash
# tunnelion (Desktop — site kayitli veya --path)
./plume.sh schedule status --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh schedule cron-install --path=/Users/me/Desktop/Projects.nosync/tunnelion --dry-run
./plume.sh schedule cron-install --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh schedule list --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh schedule run-once --path=/Users/me/Desktop/Projects.nosync/tunnelion --dry-run
./plume.sh schedule run-once --path=/Users/me/Desktop/Projects.nosync/tunnelion

cd ~/Desktop/Projects.nosync/tunnelion && ./plume.sh schedule list
./plume.sh schedule cron-install --path=/Users/me/Desktop/Projects.nosync/tunnelion --remove
```

## Hata Senaryolari

- Proje yolu bulunamaz (`--path` gerekir veya site/CWD/mode path ayarlanmali).
- `crontab` yoksa `status` icin `SCHEDULER_CRON=unknown`; `cron-install` exit `2`.
- Root ile calistirilirsa `cron-install` exit `2` (kullanici crontab'i hedeflenir).
- `artisan` yoksa `list` / `run-once` / `cron-install` exit `2`; `status` WARN ile devam eder.
- Eski Laravel surumlerinde `--no-interaction` desteklenmiyorsa `run-once` Artisan hatasi ile exit `1` doner.
- Ayni marker zaten varsa `cron-install` tekrar eklemez (exit `0`, INFO).

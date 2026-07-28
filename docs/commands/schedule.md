# `schedule` Commands

## Amac

Laravel zamanlayici operasyonlari: durum ozeti (`status`), kayitli gorev listesi (`list`), tek seferlik `schedule:run` (`run-once`). MVP'de plume kullanici crontab kurmaz; `status` ve basarili `run-once` sonrasi `CRON_HINT` ile yonlendirir.

## Kullanim

```bash
./plume.sh schedule status
./plume.sh schedule status --mode=native
./plume.sh schedule status --path=/abs/laravel-app
./plume.sh --json schedule status --path=/abs/laravel-app

./plume.sh schedule list --path=/abs/laravel-app
./plume.sh schedule run-once --path=/abs/laravel-app
./plume.sh schedule run-once --path=/abs/laravel-app --dry-run
```

## Parametreler

- `status` (varsayilan alt komut): Scheduler durumu.
- `list`: Proje dizininde `php artisan schedule:list` calistirir (Laravel 8+); cikti Artisan'a aittir.
- `run-once`: Proje dizininde `php artisan schedule:run --no-interaction` bir kez calistirir.
- `--dry-run` (`run-once`): Komutu calistirmaz; planlanan `cd ... && php artisan schedule:run --no-interaction` satirini yazar.
- `--mode=native|docker-lite|laradock-bridge`: `status` icin mod baglami (list/run-once yok sayilir).
- `--path=/abs/project`: Laravel proje kokunu zorla; verilmezse kayitli site (CWD eslesmesi), CWD'de `artisan`, veya aktif mod workspace yolu denenir.
- Global `--json`: Yalnizca `status` icin JSON cikti (`ok`, `command`, `data`).

## Cikti / Exit Codes

- `0`: Basarili (`status`, `list`, `run-once`, `run-once --dry-run`).
- `1`: Artisan komutu basarisiz (`list`, `run-once`; Laravel cikis kodu iletilir).
- `2`: Gecersiz arguman, proje yolu cozulemedi, `artisan` yok veya `php` bulunamadi.

Text `status` ciktisi: `MODE`, `PROJECT_PATH`, `PROJECT_SOURCE`, `ARTISAN` (`present|missing`), `SCHEDULER_CRON` (`configured|maybe|not-configured|unknown`), `CRON_HINT`.

`run-once`: Crontab yoksa (`not-configured`) basarili calismadan sonra INFO ile ornek crontab satiri hatirlatilir.

## Ornekler

```bash
# tunnelion (Desktop — site kayitli veya --path)
./plume.sh schedule status --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh schedule list --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh schedule run-once --path=/Users/me/Desktop/Projects.nosync/tunnelion --dry-run
./plume.sh schedule run-once --path=/Users/me/Desktop/Projects.nosync/tunnelion

cd ~/Desktop/Projects.nosync/tunnelion && ./plume.sh schedule list
```

## Hata Senaryolari

- Proje yolu bulunamaz (`--path` gerekir veya site/CWD/mode path ayarlanmali).
- `crontab` yoksa `SCHEDULER_CRON=unknown`; ipucu satiri yine yazilir.
- `artisan` yoksa `list` / `run-once` exit `2`; `status` WARN ile devam eder.
- Eski Laravel surumlerinde `--no-interaction` desteklenmiyorsa `run-once` Artisan hatasi ile exit `1` doner.

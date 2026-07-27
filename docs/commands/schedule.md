# `schedule` Commands

## Amac

Laravel `schedule:run` icin operasyonel durum ozeti: proje yolu (site/CWD/mode path), `artisan` varligi ve kullanici crontab'inda zamanlayici satiri ipuclari. MVP'de plume scheduler cron kurmaz; yalnizca durum ve ornek crontab satiri verir.

## Kullanim

```bash
./plume.sh schedule status
./plume.sh schedule status --mode=native
./plume.sh schedule status --path=/abs/laravel-app
./plume.sh --json schedule status --path=/abs/laravel-app
```

## Parametreler

- `status` (varsayilan alt komut): Scheduler durumu.
- `--mode=native|docker-lite|laradock-bridge`: Aktif mod yerine belirtilen mod (queue/horizon satirlari icin tutarli mod baglami).
- `--path=/abs/project`: Laravel proje kokunu zorla; verilmezse kayitli site (CWD eslesmesi), CWD'de `artisan`, veya aktif mod workspace yolu denenir.
- Global `--json`: JSON cikti (`ok`, `command`, `data`).

## Cikti / Exit Codes

- `0`: Basarili.
- `2`: Gecersiz arguman veya proje yolu cozulemedi.

Text ciktida ana alanlar: `MODE`, `PROJECT_PATH`, `PROJECT_SOURCE`, `ARTISAN` (`present|missing`), `SCHEDULER_CRON` (`configured|maybe|not-configured|unknown`), `CRON_HINT` (ornek `* * * * * cd ... && php artisan schedule:run ...`).

## Ornekler

```bash
cd ~/Sites/myapp && ./plume.sh schedule status
./plume.sh schedule status --path=/Users/me/Projects/myapp
```

## Hata Senaryolari

- Proje yolu bulunamaz (`--path` gerekir veya site/CWD/mode path ayarlanmali).
- `crontab` yoksa `SCHEDULER_CRON=unknown`; ipucu satiri yine yazilir.
- `artisan` yoksa WARN; cron ipucu yine gosterilir.

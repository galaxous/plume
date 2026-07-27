# `queue` Commands

## Amac

Laravel kuyruk calisanlari icin operasyonel durum: proje `.env` queue baglantisi, `PLUME_HORIZON_ENABLED` / `PLUME_SUPERVISOR_ENABLED` / `PLUME_PHP_WORKER_ENABLED` ve native veya compose runtime'daki horizon/supervisor/php_worker satirlari. MVP native modda tam supervisor kurulumu yok; durum satirlari ve `services up horizon` yonlendirmesi verilir.

## Kullanim

```bash
./plume.sh queue status
./plume.sh queue status --mode=native
./plume.sh queue status --path=/abs/laravel-app
./plume.sh --json queue status --mode=native
```

## Parametreler

- `status` (varsayilan alt komut): Kuyruk/Horizon ozeti.
- `--mode=native|docker-lite|laradock-bridge`: Servis runtime kaynagi.
- `--path=/abs/project`: Laravel proje kokunu zorla (cozumleme `schedule status` ile ayni).
- Global `--json`: JSON cikti.

## Cikti / Exit Codes

- `0`: Basarili.
- `2`: Gecersiz arguman veya proje yolu cozulemedi.

Text ciktida: `QUEUE_CONNECTION` (`.env` `QUEUE_CONNECTION` veya legacy `QUEUE_DRIVER`), `HORIZON` / `SUPERVISOR` / `PHP_WORKER` satirlari (`env=`, `enabled=`, `running=`, `health=`). Native modda Horizon acik ama calismiyorsa `./plume.sh services up horizon --mode=native` ipucu.

## Ornekler

```bash
PLUME_HORIZON_ENABLED=true ./plume.sh queue status --mode=native
./plume.sh queue status --path=/var/www/myapp --mode=docker-lite
```

## Hata Senaryolari

- Proje yolu cozulemez.
- Modda servis desteklenmiyorsa ilgili satirda `unsupported` health.
- Horizon icin supervisor zorunlulugu (`PLUME_HORIZON_REQUIRE_SUPERVISOR`) `services up horizon` ile ayni kurallara tabidir; bu komut yalnizca durum raporlar.

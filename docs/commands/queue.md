# `queue` Commands

## Amac

Laravel kuyruk operasyonlari: calisan/Horizon durumu (`status`) ve basarisiz is listesi (`list` → `queue:failed`). Native’de Horizon gercek worker (D-147): `services up horizon --mode=native` supervisor + `php artisan horizon`. `php_worker` hâlâ registry-only.

## Kullanim

```bash
./plume.sh queue status
./plume.sh queue status --mode=native
./plume.sh queue status --path=/abs/laravel-app
./plume.sh --json queue status --mode=native

./plume.sh queue list --path=/abs/laravel-app
./plume.sh queue list --mode=native --path=/abs/laravel-app
```

## Parametreler

- `status` (varsayilan alt komut): Kuyruk/Horizon ozeti.
- `list`: Proje dizininde `php artisan queue:failed` calistirir. `PLUME_HORIZON_ENABLED=true` ise ek INFO: `horizon:status` ve `./plume.sh services status horizon` onerisi.
- `--mode=native|docker-lite|laradock-bridge`: Servis runtime kaynagi (`status` ve Horizon ipucu icin).
- `--path=/abs/project`: Laravel proje kokunu zorla (cozumleme `schedule status` ile ayni).
- Global `--json`: Yalnizca `status` icin JSON cikti.

## Cikti / Exit Codes

- `0`: Basarili.
- `1`: Artisan `queue:failed` basarisiz (Laravel cikis kodu iletilir).
- `2`: Gecersiz arguman, proje yolu cozulemedi, `artisan` yok veya `php` bulunamadi.

Text `status` ciktisi: `QUEUE_CONNECTION`, `HORIZON` / `SUPERVISOR` / `PHP_WORKER` satirlari. Native modda Horizon acik ama calismiyorsa `./plume.sh services up horizon --mode=native` ipucu.

Horizon detayli durum icin plume `queue list` yerine dogrudan `php artisan horizon:status` kullanin (veya `services status horizon`).

## Ornekler

```bash
# tunnelion + Horizon env
PLUME_HORIZON_ENABLED=true ./plume.sh queue status --mode=native --path=/Users/me/Desktop/Projects.nosync/tunnelion
./plume.sh queue list --path=/Users/me/Desktop/Projects.nosync/tunnelion

./plume.sh queue status --path=/var/www/myapp --mode=docker-lite
```

## Hata Senaryolari

- Proje yolu cozulemez.
- Modda servis desteklenmiyorsa `status` satirinda `unsupported` health.
- Horizon icin supervisor zorunlulugu (`PLUME_HORIZON_REQUIRE_SUPERVISOR`) `services up horizon` ile ayni kurallara tabidir; bu komutlar yalnizca durum / Artisan sarmalayicisidir.

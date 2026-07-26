# Operations & Observability Plan

## Operasyon Komutlari (Hedef)

- `plumectl status`: Mod + servislerin anlik durumu
- `plumectl health`: Health-check raporu
- `plumectl logs`: Servis loglarina erisim
- `plumectl monitor summary`: Ozet telemetry
- `plumectl doctor --deep`: Konfig + port + process + dependency analizi

## Health-Check Modeli

- Tipler:
  - Port acik mi
  - HTTP endpoint cevap veriyor mu
  - CLI probe (ornek: `redis-cli ping`)
- Durumlar:
  - `healthy`
  - `degraded`
  - `down`
- Cikti:
  - JSON ve human-readable ozet

## Log Stratejisi

- Konum:
  - Lokal: `~/.config/plume/logs`
  - Sunucu: `/var/log/plume`
- Rotasyon:
  - Boyut tabanli (ornek 10MB x 5)
- Modlara gore kaynak:
  - native: system service loglari + plumectl action log
  - docker-lite: container logs + plumectl action log
  - laradock-bridge: docker compose logs + bridge action log

## Monitoring Scope (Baslangic)

- Service uptime
- Son 5 hata
- Port cakisma olaylari
- Son deploy/upgrade izi
- Laravel runtime metrikleri:
  - queue backlog/islenme hizi
  - failed jobs sayisi
  - horizon status
  - scheduler son calisma izi
  - deploy health gate sonucu

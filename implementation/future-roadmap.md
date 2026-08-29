# Future Roadmap (tek sayfa todo ozeti)

**Guncelleme:** 2026-08-18. Faz 1–22 kapandi (Faz 7 `beta-frozen`). Native Horizon: D-147.

| Kaynak | Rol |
|--------|-----|
| [phase-tracker.md](./phase-tracker.md) | Resmi faz durumu (master board) |
| [11-status-2026-08-18.md](./11-status-2026-08-18.md) | Son kapanis (Faz 22) |
| [10-herd-parity-and-beyond.md](./10-herd-parity-and-beyond.md) | Parity checkbox’lari |
| [phase-15-backlog-plume-yml-dockerlite.md](./phases/phase-15-backlog-plume-yml-dockerlite.md) | D-089 urun backlog |
| [native-service-contract.md](../docs/operations/native-service-contract.md) | Native “container” sozlesmesi |

---

## Sonraki faz adaylari (henuz tracker’da yok)

| Oncelik | Tema | Not |
|---------|------|-----|
| **P1** | **Docker-lite unfreeze** | D-089 |
| P2 | **meilisearch / minio native driver** | Toggle-only (D-146); Herd parity |
| P3 | **Release / dagitim** | Packagist/Homebrew, pinned release, opsiyonel auto-update |
| P4 | **Composer + Node workspace** | Herd parity; laradock/docker-lite agirlikli |
| — | **plume.yml stretch** | Registry sync, `services.enabled[]` (phase-16 stretch / 16b) |

Yeni faz acilirken: `phases/phase-NN.md` + tracker satiri + D-xxx.

---

## Herd parity — acik maddeler

Kaynak: [10-herd-parity-and-beyond.md](./10-herd-parity-and-beyond.md) (`[ ]` satirlari).

- [ ] Composer + Node dev workflow entegrasyonu
- [ ] Pinned release + optional auto-update
- [ ] Meilisearch / OpenSearch
- [ ] MinIO / S3-compatible local storage
- [ ] Websocket (Reverb / Soketi) runtime
- [ ] Cache / session / store driver uyum dogrulamasi
- [ ] `about` ve diger genisletilmis artisan health probes

**Kismen acik:** Queue/scheduler — Faz 15 baseline + Faz 21 honesty (D-146); tam native worker/supervisor host kurulumu backlog.

---

## Doc / agent hijyeni (istege bagli)

- [x] AGENTS.md §6–8, ai-assisted bootstrap (2026-07-28)
- [x] Herd parity + Mailpit doc sync — backlog B3 (2026-07-28)
- [ ] `about` probe tamamlaninca parity satirini kapat

---

## Yeni agent oturumu — hizli secim

1. **Buyuk ozellik:** P1 Docker-lite → yeni `phase-17.md` + `@AGENTS.md`; veya parity tek madde → `@implementation/10-herd-parity-and-beyond.md`
2. **Dogrulama:** `./tests/run_smoke_suite.sh --release`

Bootstrap metni: [docs/operations/ai-assisted-development.md](../docs/operations/ai-assisted-development.md) (Session bootstrap).

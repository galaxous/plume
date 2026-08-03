# Future Roadmap (tek sayfa todo ozeti)

**Guncelleme:** 2026-07-29. Faz 1–16 kapandi (Faz 7 `beta-frozen`). Detayli faz kurallari: [AGENTS.md](../AGENTS.md) §8.

| Kaynak | Rol |
|--------|-----|
| [phase-tracker.md](./phase-tracker.md) | Resmi faz durumu (master board) |
| [11-status-2026-07-29.md](./11-status-2026-07-29.md) | Son kapanis + handoff |
| [10-herd-parity-and-beyond.md](./10-herd-parity-and-beyond.md) | Parity checkbox’lari |
| [phase-15-backlog-plume-yml-dockerlite.md](./phases/phase-15-backlog-plume-yml-dockerlite.md) | D-089 urun backlog |

---

## Sonraki faz adaylari (henuz tracker’da yok)

| Oncelik | Tema | Not |
|---------|------|-----|
| P1 | **Docker-lite unfreeze** | D-089; `PLUME_DOCKER_LITE_COMPOSE_REQUIRED`, template slimming, prod-lite compose — ayri **Phase 17** onerilir |
| P2 | **Native servis genisletme** | Postgres/memcached vb. host provision veya wizard |
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

**Kismen acik:** Queue/scheduler — Faz 15 baseline tamam; tam native worker/supervisor host kurulumu manifest sinirlari (D-113).

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

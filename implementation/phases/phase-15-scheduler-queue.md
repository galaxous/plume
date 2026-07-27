# Phase 15 — Scheduler & queue ops (backlog)

Herd/Laradock parity: Laravel `schedule:run`, queue workers, Horizon — native ve docker-lite icin operasyonel komutlar.

## Checklist (not started)

- [ ] `plumectl services` alt komut veya `plume schedule` / `plume queue` stub: `list`, `run-once`, `status` (native supervisor/horizon vs docker-lite compose)
- [ ] Manifest: `services.horizon` / `php_worker` native provision sinirlari dokumante; docker-lite `laravel-horizon` ile hizalama
- [ ] Smoke: hermetik mock ile `schedule:run --dry-run` veya worker health satiri (mode matrix)
- [ ] `docs/commands/` + D-xxx karar kaydi; release smoke gate

## Baglantilar

- [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md)
- [services.md](../../docs/commands/services.md) (horizon / supervisor bagimliligi)

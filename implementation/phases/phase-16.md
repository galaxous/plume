# Phase 16 — Project `plume.yml` v2 (MVP)

## Objective

Proje kokundeki `plume.yml` dosyasini phase-4 baseline’inin otesine tasiyarak tek kaynakta **mode**, **PHP surumu** ve (dar MVP) **servis enable** bilgisini okuyup CLI davranisina yansitmak. Merkezi site registry (`~/.config/plume/sites`) ile catisma kurallari dokumante edilmeli.

## Status

- `not-started` (taslak; tracker ile hizali)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- Kaynak backlog: [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md) (D-089)
- Config taslagi: [03-config-yaml-draft.md](../03-config-yaml-draft.md)
- **Kapsam disi (ayri faz):** docker-lite unfreeze — bkz. [future-roadmap.md](../future-roadmap.md)

## MVP Scope (onerilen)

- [ ] Schema v2 taslagi: `project.mode`, `project.php_version` (ve gerekirse `project.type`)
- [ ] Loader: proje kokunden `plume.yml` okuma; mevcut mode cozumlemesi ile geriye uyum ([site_mode_resolution_smoke.sh](../../tests/site_mode_resolution_smoke.sh))
- [ ] Merge/oncelik kurali dokumani: proje `plume.yml` vs kullanici `services.yml` / `.env` (hangi alan nerede kazanir)
- [ ] En az bir CLI yolu MVP’yi kullanir (orn. `mode path` / `project` alt komutu veya `site add` icinde php_version hint)
- [ ] Hermetik smoke: gecici proje dizini + minimal `plume.yml`; gercek `~/.config/plume` yok

## Stretch (faz icinde veya 16b)

- [ ] `services.enabled[]` veya env override map
- [ ] `sites[]` ↔ registry tek yon sync veya `plume sync` tasarim notu + D-xxx

## Test Checklist

- [ ] `tests/phase16_plume_yml_v2_smoke.sh` (veya mevcut site mode smoke genisletmesi)
- [ ] `./tests/run_smoke_suite.sh --release` yesil (yeni adim release-readiness + runner’a eklenince)

## Documentation Checklist

- [ ] [03-config-yaml-draft.md](../03-config-yaml-draft.md) — v2 alanlari isaretli
- [ ] `docs/operations/` — proje manifest kullanimi (orn. project config runbook)
- [ ] Yeni/degisen komutlar → `docs/commands/`
- [ ] `docs/contracts/` — JSON ciktilari etkileniyorsa guncelle
- [ ] Decision log: **D-117+** (schema, merge order, MVP sinirlari)

## Gate Checklist (Mandatory)

- [ ] MVP scope complete
- [ ] Tests pass (`--release` / `--ci`)
- [ ] Decision log updated
- [ ] Tracker satiri `done` + tamamlanma tarihi
- [ ] [10-herd-parity-and-beyond.md](../10-herd-parity-and-beyond.md) — `plume.yml` notu guncelle (Phase 4 impact)

## Referans kod

- `lib/commands/site.sh` — mevcut `plume.yml` manifest yolu
- `tests/site_mode_resolution_smoke.sh` — mode cozumleme smoke

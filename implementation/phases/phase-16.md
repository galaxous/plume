# Phase 16 — Project `plume.yml` v2 (MVP)

## Objective

Proje kokundeki `plume.yml` dosyasini phase-4 baseline’inin otesine tasiyarak tek kaynakta **mode**, **PHP surumu** ve (dar MVP) **servis enable** bilgisini okuyup CLI davranisina yansitmak. Merkezi site registry (`~/.config/plume/sites`) ile catisma kurallari dokumante edilmeli.

## Status

- `done` (2026-07-29)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- Gate: D-117, D-118
- Kaynak backlog: [phase-15-backlog-plume-yml-dockerlite.md](./phase-15-backlog-plume-yml-dockerlite.md) (D-089)
- Config taslagi: [03-config-yaml-draft.md](../03-config-yaml-draft.md)
- **Kapsam disi (ayri faz):** docker-lite unfreeze — bkz. [future-roadmap.md](../future-roadmap.md)

## MVP Scope (onerilen)

- [x] Schema v2 taslagi: `project.mode`, `project.php_version` (ve gerekirse `project.type`)
- [x] Loader: proje kokunden `plume.yml` okuma; mevcut mode cozumlemesi ile geriye uyum ([site_mode_resolution_smoke.sh](../../tests/site_mode_resolution_smoke.sh))
- [x] Merge/oncelik kurali dokumani: proje `plume.yml` vs kullanici `services.yml` / `.env` (hangi alan nerede kazanir)
- [x] En az bir CLI yolu MVP’yi kullanir (orn. `mode path` / `project` alt komutu veya `site add` icinde php_version hint)
- [x] Hermetik smoke: gecici proje dizini + minimal `plume.yml`; gercek `~/.config/plume` yok

## Stretch (faz icinde veya 16b)

- [ ] `services.enabled[]` veya env override map
- [ ] `sites[]` ↔ registry tek yon sync veya `plume sync` tasarim notu + D-xxx

## Test Checklist

- [x] `tests/phase16_plume_yml_v2_smoke.sh` (veya mevcut site mode smoke genisletmesi)
- [x] `./tests/run_smoke_suite.sh --release` yesil (yeni adim release-readiness + runner’a eklenince)

## Documentation Checklist

- [x] [03-config-yaml-draft.md](../03-config-yaml-draft.md) — v2 alanlari isaretli
- [x] `docs/operations/` — proje manifest kullanimi (orn. project config runbook)
- [x] Yeni/degisen komutlar → `docs/commands/`
- [x] `docs/contracts/` — `project config show` key=value (JSON critical list disi; bkz. cli-output-contract.md)
- [x] Decision log: **D-117+** (schema, merge order, MVP sinirlari)

## Gate Checklist (Mandatory)

- [x] MVP scope complete
- [x] Tests pass (`--release` / `--ci`)
- [x] Decision log updated
- [x] Tracker satiri `done` + tamamlanma tarihi
- [x] [10-herd-parity-and-beyond.md](../10-herd-parity-and-beyond.md) — `plume.yml` notu guncelle (Phase 4 impact)

## Referans kod

- `lib/common/plume_yml.sh` — MVP loader
- `lib/commands/site.sh` — mode/php hint entegrasyonu
- `lib/commands/project.sh` — `project config show`
- `tests/site_mode_resolution_smoke.sh` — mode cozumleme smoke
- `tests/phase16_plume_yml_v2_smoke.sh` — hermetik v2 smoke

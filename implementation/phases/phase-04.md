# Phase 04 - Site Registry & Onboarding

## Objective

- Site registry ve onboarding akışını başlat: `plume site` komut ailesi ile prompt destekli, deterministic, conflict-aware ekleme ve yönetim.

## Scope Checklist

- [x] `site add/list/remove/check`
- [x] Prompt-based path/domain collection
- [x] `plume.yml` and site yaml placement model finalized (phase-04 baseline: project-local mode + central registry)
- [x] Nginx-first publish + host sync + nginx reload on publish (`--reload`)
- [x] `project init` bootstrap flow

## Implementation Checklist

- [x] Site registry index model
- [x] Conflict detection (domain/path)
- [x] Conflict detection (port)
- [x] Safe write + rollback on publish failure
- [x] Non-root runtime commands verified (host sync skip on permission errors by default)
- [x] `plume.yml` loading + validation (mode resolution + invalid mode fail-fast)

## Test Checklist

- [x] Add/list/remove flow tests
- [x] Invalid path/domain tests (`site add` path/domain required checks)
- [x] Nginx config publish/reload smoke tests
- [x] Host sync + port conflict smoke tests
- [x] Laravel onboarding smoke tests (`tests/phase4_site_smoke.sh` script)
- [x] Project bootstrap smoke tests (`tests/phase4_project_init_smoke.sh`)
- [x] `plume.yml` mode resolution smoke tests (`tests/site_mode_resolution_smoke.sh`)

## Documentation Checklist

- [x] `docs/commands/site.md`
- [x] `docs/commands/project.md`
- [x] `docs/operations/laravel-project-lifecycle.md`
- [x] Site onboarding implementation notes (`implementation/07-site-onboarding-and-obstacles.md`)
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-03-06 -> 2026-03-07
- Owner: @team
- Related PR/Commit: phase-04-closeout
- Open risks:
  - `plume.yml` phase-04 baseline sadece `mode` alanini garanti eder; service/site detayli schema phase-6+ tasariminda genisletilecek.
  - `project init` faz-04 kapsaminda local bootstrap adimlarini kapsar; production deploy lifecycle (rollback/health gates) phase-9+ kapsamina kalir.
  - Herd parity etkisi: hizli local onboarding omurgasi kapatildi, webserver parity faz-5'e baglandi ve tamamlandi.

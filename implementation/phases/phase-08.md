# Phase 08 - Laradock Bridge Mode

## Objective

- Var olan Laradock stack'leri uzerinde plume komutlarini native ile ayni kontratta calistiran guvenli bridge/adaptor katmani kurmak.

## Status

- `done` (started: 2026-03-10, completed: 2026-04-03)
- Priority: high (docker-lite beta-frozen, odak native + laradock-bridge parity)

## Scope Checklist

- [x] Laradock discovery (strict + non-strict path/compose algilama)
- [x] Bridge sync and state mapping (runtime/state DB parity)
- [x] Health/status checks on existing containers
- [x] Desired service-set config for Laradock lifecycle
- [x] Safe interoperability and no destructive defaults
- [x] Native ile komut-esdegerligi (same command surface, different engine)

## Implementation Checklist

- [x] Bridge adapters complete
- [x] Port/state introspection
- [x] Compatibility checks before apply (`services laradock check`)
- [x] Failure rollback behavior
- [x] Native<->laradock-bridge adapter contract normalization

## Test Checklist

- [x] Existing Laradock project integration smoke (`phase8-laradock-bootstrap-smoke`)
- [x] Bridge sync tests
- [x] Health-check/report tests
- [x] Regression tests with native unaffected
- [x] Docker-lite beta smoke unchanged

## Documentation Checklist

- [x] Laradock bridge command docs
- [x] Ops docs for bridge workflows
- [x] Support matrix updates
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-04-03
- Owner:
- Related PR/Commit:
- Open risks:
  - Laradock compose naming varyasyonlari bridge mapping'i zorlayabilir (phase9 hardening backlog).
  - Runtime source-of-truth (live docker vs state DB) drift'i periyodik `sync state` ile azaltilsa da event-level audit phase9'a birakildi.
  - APP_CODE_PATH_HOST/APP_CODE_PATH_CONTAINER strict guard icin coklu team/multi-project fixture seti phase9'da genisletilmeli.

## Next-Phase Risks (for Phase 09)

- Watch/stream komutlarinda uzun sureli terminal oturumlarinda kaynak tuketimi (cpu/io) izlenmeli.
- Production benzeri Laradock stack'lerde compose override zincirleri (`docker-compose.override.yml`, custom include) icin discovery kapsami genisletilmeli.
- Rollback davranisi lifecycle seviyesinde var; config-level transactional rollback ve backup/restore runbook phase9 kapsaminda tamamlanmali.

## Herd Parity / Beyond Review

- Herd parity:
  - Site onboarding + webserver adapter + php runtime mapping (native/laradock-bridge) hedefi saglandi.
  - Service lifecycle (`up/down/status/health/logs/exec/containers`) parity command-surface seviyesinde tamamlandi.
- Beyond Herd:
  - Desired service-set orchestration, safe-order lifecycle, failure rollback, mode-path strict guards ve state DB telemetry eklendi.
  - Phase9 odagi: observability/ops/runbook productionizasyonu.

## Active Delivery Slice

- Ilk aktif teslim dilimi:
  - [phase-08a-laradock-bridge-runtime-parity](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-08a-laradock-bridge-runtime-parity.md)
- Bu dilim Phase-08'in ilk kapanacak parcasi olarak kabul edilir.
- Odak:
  - `services up/down/status/health/logs/exec/containers --mode=laradock-bridge`
  - live docker compose state -> plume state DB normalization

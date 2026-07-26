# Phase 07 - Docker-Lite Mode

## Objective

- Docker-lite baseline'i beta seviyesinde stabilize etmek ve kalan lightweight hedeflerini backlog'a almak.

## Status

- `beta-frozen` (2026-03-10)
- Not: aktif gelistirme odagi Phase-08 (laradock-bridge) ve native parity derinlestirmesine tasindi.

## Scope Checklist

- [x] Compose/workspace model
- [x] Site publish compatibility
- [x] Service health/status parity
- [x] Majority service support parity with native
- [x] Version behavior parity (image tags/php aliases)

## Implementation Checklist

- [x] Docker-lite adapters complete
- [x] Workspace lifecycle commands
- [x] Container health checks integrated
- [x] Runtime logs and status unified output

## Test Checklist

- [x] Compose up/down/status tests
- [x] Service enable/disable behavior tests
- [x] Version pin tests
- [x] Native vs docker-lite parity checks

## Documentation Checklist

- [x] Docker-lite command docs
- [x] Support matrix update
- [x] Mode-specific env contract updates
- [x] Decision log update

## Gate Checklist (Mandatory)

- [x] Feature scope beta seviyesinde complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-03-10
- Owner: @team
- Related PR/Commit: phase-07-docker-lite-runtime-parity + phase-07-beta-freeze
- Open risks:
  - Lightweight tek-cati local/prod deployment ergonomisi hedeflenen seviyede degil; backlog'a alindi.
  - Compose/service mapping sadelemesi ve image boyut optimizasyonu sonraki docker-lite iterasyonuna ertelendi.
  - Ana odak: laradock-bridge + native modlarda tek komut yuzeyi parity'si.

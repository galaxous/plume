# Phase 05 - Multi-Mode Parity (native, docker-lite, laradock-bridge)

## Objective

- Üçlü mode modelini tek komut yüzeyi ile davranış olarak eşitlemek:
  - `native`
  - `docker-lite`
  - `laradock-bridge`
- Site kaydı ve işlem akışı (add/update/publish/check/remove), mode fark etmeksizin aynı komutlarla çalışmalı.
- Native'de hazır olan `site` davranışı; Docker-lite ve laradock-bridge için adaptorlarla aynı kontrat üzerinden devreye alınmalı.

## Scope Checklist

- [x] Apache2 adapter (baseline render/publish/remove/reload)
- [x] Caddy adapter (baseline render/publish/remove/reload)
- [x] `native|docker-lite|laradock-bridge` publish adapter contract (nginx path)
- [x] Site lifecycle parity (add/update/publish/check/remove) across modes (nginx path)
- [x] Host config sync + reload semantics parity across modes
- [x] Service operation parity across modes (`services supported/status/up/down/install/update` baseline)
- [x] Laradock strict path + compose container lifecycle uyumluluğu
- [x] Docker-lite service-compose uyumluluğu (compose preflight + strict mode)

## Implementation Checklist

- [x] Shared site publish facade: `plume_site_publish_dispatch` (mode -> adapter)
- [x] Adapter contract finalized (baseline nginx adapter flow)
  - Inputs: `site_id`, requested actions (`render|publish|remove|reload|health`), options
  - Outputs: normalized exit code + warning/error stream
- [x] Nginx adapter (existing behavior) native mode-a taşınır
- [x] Apache2 adapter
- [x] Caddy adapter
- [x] Docker-lite adapter (baseline publish/remove/reload hook)
  - `docker-compose.yml` üretimi veya kullanım şablonuna map
  - container reload / health hookları
- [x] Laradock-bridge adapter (baseline publish/remove/reload hook)
  - mevcut laradock stack path/containersa bağlanır
  - `publish/remove` idempotent davranır
- [x] Server config placement strategy
  - native: `~/.config/plume/sites/<mode>/<server>/`
  - docker-lite: `~/.config/plume/docker-lite/sites/<server>/` (compose mount/volume map)
  - laradock-bridge: laradock path altı bağları
- [x] `plume.yml` ile site hedeflemeyi mode-adapter seviyesinde çözümleme notu
- [x] Conflict/override policy
  - domain/path/port conflict her modda tek kurala tabi
  - override yalnızca `--force` ile (mevcut davranış korunur)
- [x] Config rollback and dry-run consistency

## Test Checklist

- [x] Apache2 integration checks (native + adapter modes smoke)
- [x] Caddy integration checks (native + adapter modes smoke)
- [x] Native publish/remove/list/check regression (phase-04 smoke continuation)
- [x] Docker-lite mode parity checks
  - `plume mode use docker-lite`
  - `site add/update/publish/remove`
  - `services supported/status/up/down/update` davranışları
- [x] Laradock-bridge mode parity checks
  - `plume mode use laradock-bridge`
  - `site add/update/publish/remove`
  - `services supported/status/up/down`
  - `services` ve `site` komutları için `--mode` tabanlı çalıştırma

- [x] `tests/phase5_mode_parity_smoke.sh` eklendi: mode bazlı site lifecycle + service commands smoke
- [x] `tests/phase5_apache2_adapter_smoke.sh` eklendi: apache2 adapter smoke (native/docker-lite/laradock-bridge)
- [x] `tests/phase5_caddy_adapter_smoke.sh` eklendi: caddy adapter smoke (native/docker-lite/laradock-bridge)
- [x] Reload + host sync + conflict checks in each mode
- [x] `tests/phase5_hosts_reload_parity_smoke.sh` eklendi: mode bazlı hosts sync + publish --reload parity smoke
- [x] `tests/phase5_docker_lite_compose_smoke.sh` eklendi: docker-lite compose strict/preflight smoke
- [x] `tests/phase5_laradock_strict_smoke.sh` eklendi: laradock strict path/compose/container preflight smoke
- [x] `tests/phase5_dry_run_rollback_smoke.sh` eklendi: site dry-run + failed publish rollback consistency smoke
- [x] JSON output parity testleri (services supported/status)
- [x] Non-root runtime command checks in adapter modes
- [x] `tests/phase5_non_root_runtime_smoke.sh` eklendi: adapter modlarinda non-root runtime command checks

## Documentation Checklist

- [x] `docs/commands/site.md` parity sections (`--server` + mode behavior)
- [x] `docs/commands/services.md` mode-scoped operation matrixi
- [x] Ops runbooks (native/docker-lite/laradock-bridge) for site publish and service ops
- [x] `docs/operations/site-service-ops-parity-runbook.md` eklendi
- [x] Support matrix update (`implementation/01-phased-plan.md` ve phase notes)
- [x] Decision log update (Mode-adapter mimarisi ve geriye dönük uyumluluk)
- [x] `implementation/phases/phase-04.md` "site onboarding implementation notes" maddesine phase-05 dependency link'i ekleme
- [x] `docs/commands/mode.md` güncellemesi: üç mod için aynı komut hedefleme davranışı

## Gate Checklist (Mandatory)

- [x] Feature scope complete
- [x] Tests pass
- [x] Decision log updated
- [x] Next-phase risks written
- [x] Herd parity/beyond impact reviewed

## Notes

- Date: 2026-03-07
- Owner: @team
- Related PR/Commit: phase-05a-05b
- Open risks:
- `plume.yml` ve laravel proje-local manifest ile mode-adapter eşlemesi planlamada netleştirilecek.
- Komut yüzeyindeki aynı kullanım hedefi korunmalı; mode sadece adapter seçimini etkiler.
- Phase 6 risk: service orchestration tarafinda native/docker-lite/laradock startup/health davranislarinda stricter lifecycle sozlesmesi gerekebilir.
- Herd parity impact: webserver adapter parity kapatildi; sonraki parity alanlari service orchestration ve production ops katmanina tasindi.

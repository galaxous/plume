# Phase 05 - Multi-Mode Parity (native, docker-lite, laradock-bridge)

## Objective

- Equalize the three-mode model as behavior under a single command surface:
  - `native`
  - `docker-lite`
  - `laradock-bridge`
- Site registry and operation flow (add/update/publish/check/remove) must work with the same commands regardless of mode.
- Site behavior that is ready on native must be brought online for Docker-lite and laradock-bridge through adapters on the same contract.

## Scope Checklist

- [x] Apache2 adapter (baseline render/publish/remove/reload)
- [x] Caddy adapter (baseline render/publish/remove/reload)
- [x] `native|docker-lite|laradock-bridge` publish adapter contract (nginx path)
- [x] Site lifecycle parity (add/update/publish/check/remove) across modes (nginx path)
- [x] Host config sync + reload semantics parity across modes
- [x] Service operation parity across modes (`services supported/status/up/down/install/update` baseline)
- [x] Laradock strict path + compose container lifecycle compatibility
- [x] Docker-lite service-compose compatibility (compose preflight + strict mode)

## Implementation Checklist

- [x] Shared site publish facade: `plume_site_publish_dispatch` (mode -> adapter)
- [x] Adapter contract finalized (baseline nginx adapter flow)
  - Inputs: `site_id`, requested actions (`render|publish|remove|reload|health`), options
  - Outputs: normalized exit code + warning/error stream
- [x] Nginx adapter (existing behavior) moved into native mode
- [x] Apache2 adapter
- [x] Caddy adapter
- [x] Docker-lite adapter (baseline publish/remove/reload hook)
  - Map to `docker-compose.yml` generation or usage template
  - container reload / health hooks
- [x] Laradock-bridge adapter (baseline publish/remove/reload hook)
  - binds to existing laradock stack path/containers
  - `publish/remove` behaves idempotently
- [x] Server config placement strategy
  - native: `~/.config/plume/sites/<mode>/<server>/`
  - docker-lite: `~/.config/plume/docker-lite/sites/<server>/` (compose mount/volume map)
  - laradock-bridge: bindings under the laradock path
- [x] Note on resolving site targeting with `plume.yml` at the mode-adapter level
- [x] Conflict/override policy
  - domain/path/port conflict is subject to a single rule in every mode
  - override only with `--force` (existing behavior preserved)
- [x] Config rollback and dry-run consistency

## Test Checklist

- [x] Apache2 integration checks (native + adapter modes smoke)
- [x] Caddy integration checks (native + adapter modes smoke)
- [x] Native publish/remove/list/check regression (phase-04 smoke continuation)
- [x] Docker-lite mode parity checks
  - `plume mode use docker-lite`
  - `site add/update/publish/remove`
  - `services supported/status/up/down/update` behaviors
- [x] Laradock-bridge mode parity checks
  - `plume mode use laradock-bridge`
  - `site add/update/publish/remove`
  - `services supported/status/up/down`
  - `--mode`-based execution for `services` and `site` commands

- [x] `tests/phase5_mode_parity_smoke.sh` added: mode-based site lifecycle + service commands smoke
- [x] `tests/phase5_apache2_adapter_smoke.sh` added: apache2 adapter smoke (native/docker-lite/laradock-bridge)
- [x] `tests/phase5_caddy_adapter_smoke.sh` added: caddy adapter smoke (native/docker-lite/laradock-bridge)
- [x] Reload + host sync + conflict checks in each mode
- [x] `tests/phase5_hosts_reload_parity_smoke.sh` added: mode-based hosts sync + publish --reload parity smoke
- [x] `tests/phase5_docker_lite_compose_smoke.sh` added: docker-lite compose strict/preflight smoke
- [x] `tests/phase5_laradock_strict_smoke.sh` added: laradock strict path/compose/container preflight smoke
- [x] `tests/phase5_dry_run_rollback_smoke.sh` added: site dry-run + failed publish rollback consistency smoke
- [x] JSON output parity tests (services supported/status)
- [x] Non-root runtime command checks in adapter modes
- [x] `tests/phase5_non_root_runtime_smoke.sh` added: non-root runtime command checks in adapter modes

## Documentation Checklist

- [x] `docs/commands/site.md` parity sections (`--server` + mode behavior)
- [x] `docs/commands/services.md` mode-scoped operation matrix
- [x] Ops runbooks (native/docker-lite/laradock-bridge) for site publish and service ops
- [x] `docs/operations/site-service-ops-parity-runbook.md` added
- [x] Support matrix update (`implementation/01-phased-plan.md` and phase notes)
- [x] Decision log update (mode-adapter architecture and backward compatibility)
- [x] Add phase-05 dependency link to the "site onboarding implementation notes" item in `implementation/phases/phase-04.md`
- [x] `docs/commands/mode.md` update: same command targeting behavior for all three modes

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
- Mode-adapter mapping with `plume.yml` and the Laravel project-local manifest will be clarified in planning.
- The same usage target on the command surface must be preserved; mode only affects adapter selection.
- Phase 6 risk: on the service orchestration side, a stricter lifecycle contract may be needed for native/docker-lite/laradock startup/health behavior.
- Herd parity impact: webserver adapter parity is closed; remaining parity areas moved to service orchestration and the production ops layer.

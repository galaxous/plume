# Phase 27 — Composer + Node workspace CLI (Herd parity P4)

## Objective

Native (ve docker-lite/laradock workspace) uzerinde Herd benzeri `plumectl composer|npm|node` yuzeyi; proje yolu cozumu + site PHP ile Composer.

## Status

- `done` (2026-09-29)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-154

## MVP Scope

- [x] `lib/commands/workspace.sh` — `composer` / `npm` / `node`
- [x] Proje path: `--path` / `--site` / cwd markers / mode path (npm: package.json|artisan zorunlu)
- [x] Native: PHP PATH prefix for composer; `PLUME_COMPOSER_BIN` / `PLUME_NPM_BIN` / `PLUME_NODE_BIN`
- [x] docker-lite / laradock-bridge: workspace container exec
- [x] Docs: `docs/commands/{workspace,composer,npm,node,doctor-workspace}.md`
- [x] Smoke: `phase27_workspace_composer_npm_smoke.sh`
- [x] `doctor workspace`
- [ ] Stretch (backlog): site `node_version`, nvm/fnm shim

## Gate Checklist

- [x] MVP scope (CLI + docs + smoke + doctor)
- [x] Decision log D-154
- [x] `phase27_workspace_composer_npm_smoke.sh` yesil + release suite wire
- [x] Tracker `done`
- [x] Herd parity Composer/Node MVP `[x]` (stretch ayri)

## Referans

- [workspace.md](../../docs/commands/workspace.md)
- [doctor-workspace.md](../../docs/commands/doctor-workspace.md)
- [10-herd-parity-and-beyond.md](../10-herd-parity-and-beyond.md)

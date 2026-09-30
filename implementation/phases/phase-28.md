# Phase 28 — Release packaging (Herd parity P3)

## Objective

Pinned CLI version + GitHub release + Homebrew formula + Packagist (`galaxous/laravel-plume`) dagitim yuzeyi.

## Status

- `done` (2026-09-29)
- Tracker: [phase-tracker.md](../phase-tracker.md)
- ADR: D-155

## MVP Scope

- [x] Repo `VERSION` tek kaynak; `plumectl version` / `--json` okur
- [x] [docs/operations/release.md](../../docs/operations/release.md) + [install.md](../../docs/operations/install.md)
- [x] Manual release workflow smoke → `./tests/run_smoke_suite.sh --release`
- [x] Homebrew: `packaging/homebrew/plumectl.rb` + `Formula/plumectl.rb`
- [x] Packagist: root `composer.json` (`galaxous/laravel-plume`, `bin/plumectl`)
- [x] Linux: `packaging/linux/install.sh` + install.md A–H (Debian/Ubuntu, RHEL/Fedora, diger)
- [x] `LICENSE` (MIT)
- [ ] Stretch: dedicated `homebrew-plume` tap CI, live sha256 on every release automation, `self-update` command, `.deb`/`.rpm`

## Gate Checklist

- [x] MVP docs + VERSION + workflow + packaging + smoke phase28
- [x] Decision log D-155
- [x] Tracker `done`
- [x] Herd parity “Pinned release” `[x]` (auto-update = brew/composer upgrade)

## Referans

- [release-readiness.md](../../docs/operations/release-readiness.md)
- [install.md](../../docs/operations/install.md)
- [manual-release.yml](../../.github/workflows/manual-release.yml)

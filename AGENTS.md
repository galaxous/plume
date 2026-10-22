# AGENTS Instructions (Project Local)

AI/agent working rules for this project:

1. Documentation is mandatory.
- Every code change must update related documentation files in the same PR/change.
- A code change without matching docs is considered incomplete.
- Docs site: VitePress in `docs/` (`cd docs && npm run docs:dev`; https://galaxous.github.io/plume/). Keep `docs/commands|operations|contracts` paths stable for smokes/AGENTS.

2. Commands must be documented.
- Every new `plumectl` command needs a separate doc under `docs/commands/`.
- Command docs must include these sections:
  - purpose
  - usage
  - parameters
  - output/exit-code
  - examples
  - error scenarios

3. Phase-gate discipline is mandatory.
- Do not start the next phase until the current one is complete.
- Phase completion criteria: tests + documentation + decision record.

4. Adapter-readiness must be considered.
- CLI outputs should be as stable and parseable as possible.
- Contracts under `docs/contracts/` must be checked on every change.

5. Smoke tests and AI development
- Default pre-PR verification: `./tests/run_smoke_suite.sh --release` (CI: `--ci`).
- Smoke scripts must be hermetic (temporary HOME/PLUME_STATE_DIR; real `~/.config/plume` is never used).
- Test/shell patterns: mock brew PATH, pipefail+grep, nginx strict env — see the guide below.
- For new AI sessions, session bootstrap and full strategy: [docs/operations/ai-assisted-development.md](docs/operations/ai-assisted-development.md).

6. Repo and product identity
- Product: Plume; official CLI: `plumectl`; local wrapper: `./plume.sh`.
- GitHub: [galaxous/plume](https://github.com/galaxous/plume) (local folder name may be e.g. `larasite`).
- User state: `~/.config/plume` — NEVER use it in smoke/tests (hermetic `HOME` / `PLUME_STATE_DIR`).

7. Configuration layers
- Stack manifest: `~/.config/plume/services.yml` (D-103/D-104) — see [docs/operations/services-manifest.md](docs/operations/services-manifest.md).
- Environment: `~/.config/plume/.env` (`.env` wins over the manifest).
- Machine profile: `host.env` (TCC/path; not a service enable toggle).
- Project: `plume.yml` MVP (Phase 16, D-117) — [docs/operations/project-plume-yml.md](docs/operations/project-plume-yml.md); broader schema / registry sync remains stretch backlog.

8. New phase / new agent session
- Start by reading: [implementation/phase-tracker.md](implementation/phase-tracker.md), latest `implementation/11-status-*.md`.
- Phases 1–23 are complete (Phase 7 beta-frozen); new feature = new `implementation/phases/phase-NN.md` + phase-tracker row.
- Phase close: checklist `[x]`, [implementation/05-decision-log.md](implementation/05-decision-log.md) (D-xxx), related `docs/commands/` + `docs/contracts/`, `./tests/run_smoke_suite.sh --release`.
- Session bootstrap: [docs/operations/ai-assisted-development.md](docs/operations/ai-assisted-development.md).
- Product backlog: [implementation/future-roadmap.md](implementation/future-roadmap.md); last close: [implementation/11-status-2026-08-30.md](implementation/11-status-2026-08-30.md); source: [phase-15-backlog-plume-yml-dockerlite.md](implementation/phases/phase-15-backlog-plume-yml-dockerlite.md) (D-089).
- No active phase; next candidate P2 meilisearch/minio. Phases 27–28 (Composer/Node + Release Homebrew/Packagist) are closed.
- Git: do not commit user `.env` / secret files; commit only when the user asks.

9. Native stack — OS matrix (Phase 17+)
- Priority: **macOS** (Homebrew) and **Linux** (apt, dnf); full Windows native stack is not supported.
- Every new native service PR must update [docs/operations/native-stack-os-matrix.md](docs/operations/native-stack-os-matrix.md), add mock smoke, and update `docs/commands/`.
- macOS host setup: TCC/brew approval — [docs/operations/macos-permissions.md](docs/operations/macos-permissions.md).
- Linux smoke: mock `apt-get`/`dnf` + fake `systemctl` (do not use real `~/.config/plume`).

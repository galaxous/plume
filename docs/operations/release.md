# Release (pinned version) — Phase 28 / D-155

## Purpose

Read the Plume CLI version from a single source (`VERSION`); keep GitHub Release + **Homebrew** + **Packagist** distribution surfaces ready.

## Version

- File: [`VERSION`](../../VERSION) at the repo root (semver, e.g. `0.3.0`)
- CLI: `plumectl version` or `plumectl --version`
- JSON: `plumectl --json version` → `{"ok":true,"command":"version","data":{"name":"plumectl","version":"…"}}`

## Install (user) — staged

Full checklist (Homebrew + Debian/Ubuntu + RHEL/Fedora + general Linux + maintainer):

→ **[install.md](./install.md)**

Short:

| Platform | Command |
|----------|--------|
| macOS | `brew tap galaxous/plume https://github.com/galaxous/plume && brew install plumectl` |
| Linux | `curl -fsSL …/packaging/linux/install.sh \| env PLUME_REF=v0.3.0 PREFIX=/usr/local sudo -E bash` |
| Anywhere | `composer global require galaxous/laravel-plume` |

## Publish steps (maintainer)

1. Local: `./tests/run_smoke_suite.sh --release` (optional; CI also runs it)
2. GitHub Actions → **Manual Release** (`workflow_dispatch`)
   - Smoke gate (`--release`)
   - `autonomous-tag` → tag name
   - **`packaging/homebrew/sync-release-version.sh`**: `VERSION` + `Formula/plumectl.rb` + `packaging/homebrew/plumectl.rb` `version` / `url` (same commit; `sha256` untouched)
   - Tag force-moved to this commit → GitHub Release
3. After release (optional / brew audit):
   - Compute tag tarball sha256 → write formula `sha256` on `main` (**no retag**)
   - Packagist (`galaxous/laravel-plume`): webhook / “Update” (first time: [submit](https://packagist.org/packages/submit))
4. `update-changelog.yml` updates CHANGELOG.md

Manual sync of `VERSION` / formula `version`+`url` is **not required** — Manual Release CI does it. Local trial:

```bash
./packaging/homebrew/sync-release-version.sh v0.3.1
```

## Auto-update

- Homebrew: `brew upgrade plumectl`
- Composer: `composer global update galaxous/laravel-plume`
- There is also no `plumectl self-update` (intentional; package managers are enough)

## Related

- [install.md](./install.md)
- [release-readiness.md](./release-readiness.md)
- [naming-policy.md](./naming-policy.md)
- [phase-28.md](../../implementation/phases/phase-28.md)
- Sync script: [`packaging/homebrew/sync-release-version.sh`](../../packaging/homebrew/sync-release-version.sh)
- Workflow: [`.github/workflows/manual-release.yml`](../../.github/workflows/manual-release.yml)

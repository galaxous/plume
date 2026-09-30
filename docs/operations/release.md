# Release (pinned version) — Faz 28 / D-155

## Amac

Plume CLI surumunu tek kaynaktan (`VERSION`) okumak; GitHub Release + **Homebrew** + **Packagist** dagitim yuzeylerini hazir tutmak.

## Surum

- Dosya: repo kokunde [`VERSION`](../../VERSION) (semver, orn. `0.3.0`)
- CLI: `plumectl version` veya `plumectl --version`
- JSON: `plumectl --json version` → `{"ok":true,"command":"version","data":{"name":"plumectl","version":"…"}}`

## Kurulum (kullanici) — asamali

Tam checklist (Homebrew + Debian/Ubuntu + RHEL/Fedora + genel Linux + maintainer):

→ **[install.md](./install.md)**

Kisa:

| Platform | Komut |
|----------|--------|
| macOS | `brew tap galaxous/plume https://github.com/galaxous/plume && brew install plumectl` |
| Linux | `curl -fsSL …/packaging/linux/install.sh \| env PLUME_REF=v0.3.0 PREFIX=/usr/local sudo -E bash` |
| Her yer | `composer global require galaxous/laravel-plume` |

## Yayin adimlari (maintainer)

1. `VERSION` guncelle; `packaging/homebrew/plumectl.rb` + `Formula/plumectl.rb` icinde `url`/`version` senkronla
2. Yerel: `./tests/run_smoke_suite.sh --release`
3. GitHub Actions → **Manual Release** (`workflow_dispatch`) — smoke gate + tag + Release
4. Release sonrasi:
   - Tag tarball sha256 hesapla → formula `sha256` alanini guncelle (artik `:no_check` kaldir)
   - Packagist (`galaxous/laravel-plume`): webhook / “Update” (ilk kez [submit](https://packagist.org/packages/submit))
5. `update-changelog.yml` CHANGELOG.md gunceller

## Auto-update

- Homebrew: `brew upgrade plumectl`
- Composer: `composer global update galaxous/laravel-plume`
- Ayrica `plumectl self-update` yok (bilinçli; paket yoneticileri yeterli)

## Iliskili

- [install.md](./install.md)
- [release-readiness.md](./release-readiness.md)
- [naming-policy.md](./naming-policy.md)
- [phase-28.md](../../implementation/phases/phase-28.md)

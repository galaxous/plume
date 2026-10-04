# Plume install and publish — staged guide (macOS Homebrew + Linux)

This document walks through what **you (the maintainer)** must do and the step-by-step install order for **users** on macOS / Linux.

- Official CLI: **`plumectl`** (alias: `plume`)
- Version source: repo [`VERSION`](../../VERSION)
- Related: [release.md](./release.md), [release-readiness.md](./release-readiness.md), [first-run-onboarding.md](./first-run-onboarding.md)

---

## A) Maintainer — first publish (in order)

The stages below are done **in order**. Do not skip Linux: Packagist + `packaging/linux/install.sh` are the primary path for Linux users.

### A1. Local verification (optional)

```bash
./tests/phase28_release_version_smoke.sh
./tests/run_smoke_suite.sh --release
```

You do **not** need to sync `VERSION` + Homebrew formula `version`/`url` by hand — Manual Release CI (`sync-release-version.sh`) writes them in a single commit before the tag.

Local trial:

```bash
./packaging/homebrew/sync-release-version.sh v0.3.0
```

### A2. GitHub Release (single workflow)

1. GitHub Actions → **Manual Release** (`workflow_dispatch`).
2. Smoke → tag name → `VERSION` + both `plumectl.rb` files (`version`/`url`) → force-tag → Release.
3. `sha256` is **not** updated in this step (`:no_check` may remain). For brew audit later, on `main` **without retag**:
   ```bash
   curl -sL "https://github.com/galaxous/plume/archive/refs/tags/v0.3.0.tar.gz" | shasum -a 256
   # write the digest into Formula + packaging/homebrew files, commit, push
   ```

### A3. Homebrew (macOS)

**Option 1 — formula from the same repo (immediate):**

```bash
# developer machine or documentation example
brew install --formula ./packaging/homebrew/plumectl.rb
```

**Option 2 — tap (recommended long-term):**

1. Users:
   ```bash
   brew tap galaxous/plume https://github.com/galaxous/plume
   brew install plumectl
   ```
2. The repo already has `Formula/plumectl.rb`; the tap uses that file.
3. Upgrade: `brew upgrade plumectl`

If there is no tag yet: `brew install --HEAD --formula ./packaging/homebrew/plumectl.rb`.

### A4. Packagist (shared for macOS + Linux)

1. https://packagist.org/packages/submit → GitHub: `https://github.com/galaxous/plume`
2. Package name: **`galaxous/laravel-plume`** (`composer.json`)
3. Enable GitHub webhook / Packagist “Auto-Update”
4. Verify:
   ```bash
   composer global require galaxous/laravel-plume
   plumectl version
   ```

### A5. Linux distribution surface (distro-agnostic)

There is no separate `.deb`/`.rpm` for Debian/Ubuntu **or** RHEL/Fedora yet; official Linux paths:

| Path | Who for |
|-----|----------|
| `packaging/linux/install.sh` | One-command install (PREFIX) |
| `composer global require` | Server/dev with PHP/Composer |
| `git clone` + `make install` | Contribution / development |

`install.sh` with a release tag:

```bash
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  sudo env PLUME_REF=v0.3.0 PREFIX=/usr/local bash
```

(On first use the raw URL pulls the script from `main`; `PLUME_REF` selects the checkout tag.)

---

## B) User — macOS (Homebrew) staged

### B1. Plume CLI

```bash
brew tap galaxous/plume https://github.com/galaxous/plume
brew install plumectl
# or from a clone:
# brew install --formula ./packaging/homebrew/plumectl.rb

plumectl version
```

### B2. Onboarding

```bash
plumectl env init
plumectl init host
plumectl init onboarding          # --fix if needed
plumectl init permissions --interactive   # TCC / FDA (nginx + php-fpm)
plumectl doctor workspace
plumectl doctor web
```

### B3. Stack + site

```bash
plumectl services up @core --mode=native
plumectl site add --path=/path/to/app --domain=myapp.test --server=nginx --publish --horizon
```

Upgrade: `brew upgrade plumectl`

---

## C) User — Linux (Debian / Ubuntu — apt)

### C1. System tools

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates
# if you will use the Composer path:
sudo apt-get install -y php-cli php-xml php-mbstring php-curl unzip
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### C2. Plume CLI (pick one)

**A — install.sh (recommended, distro-agnostic):**

```bash
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  sudo env PLUME_REF=v0.3.0 PREFIX=/usr/local bash
# if you do not want root:
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  env PLUME_REF=v0.3.0 PREFIX="$HOME/.local" bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

plumectl version
```

**B — Composer:**

```bash
composer global require galaxous/laravel-plume
# PATH: ~/.config/composer/vendor/bin or ~/.composer/vendor/bin
plumectl version
```

**C — Clone + make:**

```bash
git clone https://github.com/galaxous/plume.git
cd plume
sudo make install    # /usr/local/bin/plumectl
plumectl version
```

### C3. Onboarding + native stack note

```bash
plumectl env init
plumectl init host
plumectl init onboarding
plumectl doctor workspace
# Native services: apt packages (nginx, php-fpm, redis, mariadb, supervisor, …)
# with PLUME_NATIVE_HOST_PROVISION=true, plumectl services up …
```

OS matrix detail: [native-stack-os-matrix.md](./native-stack-os-matrix.md)

---

## D) User — Linux (RHEL / Fedora / CentOS — dnf)

### D1. System tools

```bash
sudo dnf install -y git curl ca-certificates
# Composer path:
sudo dnf install -y php-cli php-xml php-mbstring php-json unzip
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### D2. Plume CLI

Same as Debian: **`install.sh` / Composer / `make install`** (section C2).  
PREFIX examples: `/usr/local` or `"$HOME/.local"`.

### D3. Onboarding

Same as section C3; package names via `dnf` (`nginx`, `php-fpm`, `redis`, `mariadb-server`, `supervisor`, …) — [native-stack-os-matrix.md](./native-stack-os-matrix.md).

---

## E) User — Linux (other / Alpine / Arch — general)

1. Install `git`, `bash`, `curl`.
2. Use **`packaging/linux/install.sh`** or **Composer global** (no distro package).
3. `plumectl init host` → `package_manager` is detected; on an unknown PM, native provision may be limited — check `doctor host`.
4. Install the stack by hand if needed, or switch to `docker-lite` / `laradock-bridge` mode.

---

## F) Shared post-install checklist

```bash
plumectl version
which plumectl
plumectl doctor workspace
plumectl doctor check --mode=native
plumectl init onboarding
```

macOS extra: `plumectl init permissions --interactive`  
Linux extra: touch firewall / SELinux (RHEL) if needed; for port 80 use root/`setcap` or Plume’s elevated nginx flow.

---

## G) Summary table

| Platform | CLI install | Upgrade |
|----------|-------------|---------|
| macOS | `brew tap` + `brew install plumectl` | `brew upgrade plumectl` |
| Debian/Ubuntu | `install.sh` or Composer | re-run script / `composer global update` |
| RHEL/Fedora | same `install.sh` / Composer | same |
| Other Linux | `install.sh` / Composer / clone | same |
| All OS (dev) | `git clone` + `make install` | `git pull` + `make install` |

---

## H) Maintainer at-a-glance checklist

- [ ] `./tests/run_smoke_suite.sh --release` (optional; CI also runs it)
- [ ] GitHub Manual Release → tag `vX.Y.Z` (CI: VERSION + formula version/url)
- [ ] (Optional) Formula `sha256` → `main` (no retag)
- [ ] Packagist submit / auto-update
- [ ] Verify `install.sh` + [this document](./install.md) links in the README
- [ ] Try `brew install` on macOS
- [ ] Try `install.sh` on Ubuntu and Fedora (or in a container)
- [ ] Try `composer global require galaxous/laravel-plume`

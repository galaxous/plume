# Plume kurulum ve yayin — asamali rehber (macOS Homebrew + Linux)

Bu dokuman **senin (maintainer)** yapman gerekenleri ve **kullanicinin** macOS / Linux’ta kurulum sirasini adim adim anlatir.

- Resmi CLI: **`plumectl`** (alias: `plume`)
- Surum kaynagi: repo [`VERSION`](../../VERSION)
- Iliskili: [release.md](./release.md), [release-readiness.md](./release-readiness.md), [first-run-onboarding.md](./first-run-onboarding.md)

---

## A) Maintainer — ilk yayin (sirayla)

Asagidaki asamalar **sira ile** yapilir. Linux’u atlama: Packagist + `packaging/linux/install.sh` Linux kullanicilarinin birincil yolu.

### A1. Surum ve formula senkron

1. `VERSION` dosyasini hedef semver yap (orn. `0.3.0`).
2. `packaging/homebrew/plumectl.rb` ve `Formula/plumectl.rb` icinde:
   - `version "0.3.0"`
   - `url ".../tags/v0.3.0.tar.gz"`
3. Yerel dogrulama:
   ```bash
   ./tests/phase28_release_version_smoke.sh
   ./tests/run_smoke_suite.sh --release
   ```

### A2. GitHub Release

1. GitHub Actions → **Manual Release** (`workflow_dispatch`).
2. Smoke gate gecince tag + Release olusur (orn. `v0.3.0`).
3. Tag tarball sha256 hesapla ve formula’ya yaz (artik `sha256 :no_check` kaldir):
   ```bash
   curl -sL "https://github.com/galaxous/plume/archive/refs/tags/v0.3.0.tar.gz" | shasum -a 256
   ```
4. Formula commit’ini `main`’e push et (tap / `brew install` stabil olsun).

### A3. Homebrew (macOS)

**Seçenek 1 — ayni repodan formula (hemen):**

```bash
# gelistirici makinesi veya dokumantasyon ornegi
brew install --formula ./packaging/homebrew/plumectl.rb
```

**Seçenek 2 — tap (onerilen uzun vadeli):**

1. Kullanicilar:
   ```bash
   brew tap galaxous/plume https://github.com/galaxous/plume
   brew install plumectl
   ```
2. Repo’da `Formula/plumectl.rb` zaten var; tap bu dosyayi kullanir.
3. Upgrade: `brew upgrade plumectl`

Ilk seferde tag yoksa: `brew install --HEAD --formula ./packaging/homebrew/plumectl.rb`.

### A4. Packagist (macOS + Linux ortak)

1. https://packagist.org/packages/submit → GitHub: `https://github.com/galaxous/plume`
2. Paket adi: **`galaxous/laravel-plume`** (`composer.json`)
3. GitHub webhook / Packagist “Auto-Update” ac
4. Dogrula:
   ```bash
   composer global require galaxous/laravel-plume
   plumectl version
   ```

### A5. Linux dagitim yuzeyi (distro-agnostic)

Debian/Ubuntu **veya** RHEL/Fedora icin ayri `.deb`/`.rpm` su an yok; Linux icin resmi yollar:

| Yol | Kim icin |
|-----|----------|
| `packaging/linux/install.sh` | Tek komut kurulum (PREFIX) |
| `composer global require` | PHP/Composer olan sunucu/dev |
| `git clone` + `make install` | Katki / gelistirme |

`install.sh` release tag ile:

```bash
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  sudo env PLUME_REF=v0.3.0 PREFIX=/usr/local bash
```

(Ilk seferde raw URL `main`’deki script’i ceker; `PLUME_REF` checkout tag’ini secer.)

---

## B) Kullanici — macOS (Homebrew) asamali

### B1. Plume CLI

```bash
brew tap galaxous/plume https://github.com/galaxous/plume
brew install plumectl
# veya clone uzerinden:
# brew install --formula ./packaging/homebrew/plumectl.rb

plumectl version
```

### B2. Onboarding

```bash
plumectl env init
plumectl init host
plumectl init onboarding          # gerekirse --fix
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

## C) Kullanici — Linux (Debian / Ubuntu — apt)

### C1. Sistem araclari

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates
# Composer yolu kullanacaksan:
sudo apt-get install -y php-cli php-xml php-mbstring php-curl unzip
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### C2. Plume CLI (birini sec)

**A — install.sh (onerilen, distro bagimsiz):**

```bash
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  sudo env PLUME_REF=v0.3.0 PREFIX=/usr/local bash
# root istemezsen:
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  env PLUME_REF=v0.3.0 PREFIX="$HOME/.local" bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

plumectl version
```

**B — Composer:**

```bash
composer global require galaxous/laravel-plume
# PATH: ~/.config/composer/vendor/bin veya ~/.composer/vendor/bin
plumectl version
```

**C — Clone + make:**

```bash
git clone https://github.com/galaxous/plume.git
cd plume
sudo make install    # /usr/local/bin/plumectl
plumectl version
```

### C3. Onboarding + native stack notu

```bash
plumectl env init
plumectl init host
plumectl init onboarding
plumectl doctor workspace
# Native servisler: apt paketleri (nginx, php-fpm, redis, mariadb, supervisor, …)
# PLUME_NATIVE_HOST_PROVISION=true ile plumectl services up …
```

Detay OS matrisi: [native-stack-os-matrix.md](./native-stack-os-matrix.md)

---

## D) Kullanici — Linux (RHEL / Fedora / CentOS — dnf)

### D1. Sistem araclari

```bash
sudo dnf install -y git curl ca-certificates
# Composer yolu:
sudo dnf install -y php-cli php-xml php-mbstring php-json unzip
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
```

### D2. Plume CLI

Debian ile **ayni** `install.sh` / Composer / `make install` (bolum C2).  
PREFIX ornekleri: `/usr/local` veya `"$HOME/.local"`.

### D3. Onboarding

Bolum C3 ile ayni; paket adlari `dnf` (`nginx`, `php-fpm`, `redis`, `mariadb-server`, `supervisor`, …) — [native-stack-os-matrix.md](./native-stack-os-matrix.md).

---

## E) Kullanici — Linux (diger / Alpine / Arch — genel)

1. `git`, `bash`, `curl` kur.
2. **`packaging/linux/install.sh`** veya **Composer global** kullan (distro paketi yok).
3. `plumectl init host` → `package_manager` algilanir; bilinmeyen PM’de native provision sinirli olabilir — `doctor host` kontrol et.
4. Gerekirse stack’i elle kur veya `docker-lite` / `laradock-bridge` moda gec.

---

## F) Kurulum sonrasi ortak kontrol listesi

```bash
plumectl version
which plumectl
plumectl doctor workspace
plumectl doctor check --mode=native
plumectl init onboarding
```

macOS ek: `plumectl init permissions --interactive`  
Linux ek: firewall / SELinux (RHEL) gerekirse dokun; port 80 icin root/`setcap` veya Plume elevated nginx akisi.

---

## G) Ozet tablo

| Platform | CLI kurulum | Upgrade |
|----------|-------------|---------|
| macOS | `brew tap` + `brew install plumectl` | `brew upgrade plumectl` |
| Debian/Ubuntu | `install.sh` veya Composer | script’i tekrar / `composer global update` |
| RHEL/Fedora | ayni `install.sh` / Composer | ayni |
| Diger Linux | `install.sh` / Composer / clone | ayni |
| Tum OS (dev) | `git clone` + `make install` | `git pull` + `make install` |

---

## H) Maintainer tek bakis checklist

- [ ] `VERSION` + formula `version`/`url` senkron
- [ ] `./tests/run_smoke_suite.sh --release`
- [ ] GitHub Manual Release → tag `vX.Y.Z`
- [ ] Formula `sha256` guncelle ve push
- [ ] Packagist submit / auto-update
- [ ] `install.sh` + [bu dokuman](./install.md) linklerini README’de dogrula
- [ ] macOS’ta `brew install` dene
- [ ] Ubuntu ve Fedora’da (veya container’da) `install.sh` dene
- [ ] `composer global require galaxous/laravel-plume` dene

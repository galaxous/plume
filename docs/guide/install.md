# Install

Short path for users. Full maintainer + distro checklist: [operations/install](/operations/install).

## macOS (Homebrew)

```bash
brew tap galaxous/plume https://github.com/galaxous/plume
brew install plumectl
plumectl version
```

## Linux

```bash
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  sudo env PLUME_REF=v0.3.0 PREFIX=/usr/local bash
plumectl version
```

User-local (no sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/galaxous/plume/main/packaging/linux/install.sh | \
  env PLUME_REF=v0.3.0 PREFIX="$HOME/.local" bash
```

## Composer (any OS)

```bash
composer global require galaxous/laravel-plume
# ensure Composer global bin is on PATH
plumectl version
```

## Development clone

```bash
git clone https://github.com/galaxous/plume.git
cd plume
make install
```

## After install

Continue with [Getting started](./getting-started.md) → [First-run](./first-run.md).

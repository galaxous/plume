# Getting started

Plume (`plumectl`) is a Laravel local-ops CLI. Pick a mode, bring up the stack, add a site.

## 1. Install the CLI

See [Install](./install.md) (Homebrew, Linux `install.sh`, Composer, or clone).

## 2. First-run onboarding

```bash
plumectl env init
plumectl init host
plumectl init onboarding
plumectl doctor workspace
plumectl doctor web
```

Full walkthrough: [First-run onboarding](./first-run.md)  
macOS TCC/FDA: [macOS permissions](./macos-permissions.md)

## 3. Start core services + site

```bash
plumectl services up @core --mode=native
plumectl site add --path=/path/to/app --domain=myapp.test --server=nginx --publish
```

## Next

- [Commands index](/commands/README)
- [Operations index](/operations/README)
- [CLI output contract](/contracts/cli-output-contract)

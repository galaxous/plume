# Plume Documentation

Source markdown for Plume (commands, operations, contracts) **and** the public docs site (VitePress).

## Mandatory rule

- Every code change must also update the related documentation file.
- Work is not considered complete if documentation was not updated.

## Contents

| Path | Purpose |
|------|---------|
| `guide/` | Short user journeys for the docs site |
| `commands/` | One file per `plumectl` command |
| `operations/` | Runbooks and ops contracts |
| `contracts/` | CLI output / exit-code contracts |
| `.vitepress/` | VitePress site config |

`.env` contract: [operations/env-contract.md](./operations/env-contract.md)

## Docs site (VitePress)

```bash
cd docs
npm install
npm run docs:dev      # http://localhost:5173
npm run docs:build
npm run docs:preview
```

From repo root:

```bash
npm --prefix docs install
npm --prefix docs run docs:dev
```

Existing `commands/` / `operations/` / `contracts/` paths stay stable for AGENTS.md and smoke tests.

## Naming policy

- Product: `Plume`
- Official CLI: `plumectl`
- Optional alias: `plume`
- Repo: `plume` (GitHub); Packagist/formula: `laravel-plume`

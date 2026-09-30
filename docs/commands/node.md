# `node` Command

## Amac

Proje dizininde Node calistirir. Detay: [workspace.md](./workspace.md) (D-154).

## Kullanim

```bash
plumectl node -v
plumectl node --path=/abs/app script.js
```

## Parametreler

`--path=`, `--site=`, `--mode=` — bkz. [workspace.md](./workspace.md).

## Cikti / exit-code

node exit kodu; Plume hata `2`.

## Ornekler

```bash
plumectl node -e 'console.log(1)'
```

## Hata senaryolari

- `node not found` — Node.js veya `PLUME_NODE_BIN`

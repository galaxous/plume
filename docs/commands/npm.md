# `npm` Command

## Amac

Proje dizininde npm calistirir. Detay: [workspace.md](./workspace.md) (D-154).

## Kullanim

```bash
plumectl npm install
plumectl npm run build
plumectl npm --path=/abs/app run dev
```

## Parametreler

`--path=`, `--site=`, `--mode=` — bkz. [workspace.md](./workspace.md).

## Cikti / exit-code

npm exit kodu; Plume hata `2`.

## Ornekler

```bash
plumectl npm -v
plumectl npm ci
```

## Hata senaryolari

- `npm not found` — Node.js veya `PLUME_NPM_BIN`
- Compose yok (docker mode) — workspace init

# `doctor workspace`

## Amac

Composer / npm / node host binary ve Plume workspace CLI hazirligini teşhis eder (D-154 / Faz 27).

## Kullanim

```bash
plumectl doctor workspace
plumectl doctor workspace --strict
plumectl doctor workspace --mode=native
```

## Parametreler

- `--mode=native|docker-lite|laradock-bridge`
- `--strict`: kritik FAIL varken exit 2

## Cikti / exit-code

- `0`: OVERALL OK (WARN olabilir)
- `2`: `--strict` ve kritik FAIL

## Ornekler

```bash
plumectl doctor workspace
```

## Hata senaryolari

- `composer` / `npm` / `node` WARN — ilgili binary veya `PLUME_*_BIN`
- docker mode: workspace container yolu; compose init gerekebilir

Iliskili: [workspace.md](./workspace.md)

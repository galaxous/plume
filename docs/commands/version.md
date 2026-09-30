# `version` Command

## Amac

CLI surumunu gosterir. Kaynak: repo `VERSION` (D-155).

## Kullanim

```bash
plumectl version
plumectl --version
plumectl -v
plumectl --json version
```

## Parametreler

Yok (global `--json` desteklenir).

## Cikti / exit-code

- Text: `plumectl <semver>`
- JSON: `{"ok":true,"command":"version","data":{"name":"plumectl","version":"<semver>"}}`
- Exit `0`

## Ornekler

```bash
plumectl version
```

## Hata senaryolari

- `VERSION` yoksa `0.0.0-dev` basilir

Iliskili: [release.md](../operations/release.md)

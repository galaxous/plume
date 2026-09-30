# `doctor supervisor`

## Amac

Native supervisor kurulumunu, sistem birimini (brew services / systemd), legacy Plume daemon kalintisini, paket upgrade ihtiyacini ve kayitli program conf'larini teşhis etmek (D-149).

## Kullanim

```bash
./plume.sh doctor supervisor
./plume.sh doctor supervisor --strict
```

## Parametreler

- `--mode=native` (varsayilan: aktif mode)
- `--strict`: kritik FAIL veya upgrade WARN iken exit 2

Host bilgisi `~/.config/plume/host.env` cache'inden okunur (`package_manager`, `supervisor_*`). Eksikse `init host --force` onerilir.

## Cikti / exit-code

- `0`: OVERALL OK (WARN olabilir)
- `2`: `--strict` ve kritik FAIL / upgrade gerekli

Remediation satiri (upgrade gerekiyorsa):

```text
REMEDIATION  run: ./plume.sh services supervisor upgrade --force --yes
```

## Ornekler

```bash
./plume.sh doctor supervisor --strict
./plume.sh init host --force
```

## Hata senaryolari

- `supervisord` / `supervisorctl` yok — `services install supervisor`
- Legacy Plume-owned supervisord — `services supervisor upgrade --force --yes`
- `horizon-program` WARN — `plumectl site update <id> --horizon` sonra `plumectl services up horizon`
- Site basina kontrol: `horizon-program:<site-id>` (D-150)
- Program not RUNNING — `plumectl services logs horizon --site=<id>` ve `plumectl services restart horizon --site=<id>` (D-152; supervisorctl gerekmez)

Iliskili: [services-supervisor.md](./services-supervisor.md), [services-horizon.md](./services-horizon.md).

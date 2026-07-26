# services provision

## Amaç

Native modda `~/.config/plume/services.yml` manifest’ine göre host paketlerini kurmak ve (tanımlıysa) başlatmak.

**Native otomatik kurulum:** web (nginx/apache2 driver), MariaDB/MySQL, Redis; manifest `php.versions` listesi için best-effort host PHP (brew/apt).

**Yalnızca YAML/env toggle (native paket yok):** postgres, mailpit, memcached, rabbitmq, mongodb, phpmyadmin, horizon, vb. — `enabled: true` env’i yükler; kurulum için docker-lite, laradock-bridge veya manuel adımlar.

## Kullanım

```bash
plumectl services provision --from-manifest [--dry-run]
```

Eşdeğer:

```bash
plumectl init host --apply
```

(`init host` ayrıca `host.env` yazar ve eksikse manifest şablonunu kopyalar.)

## Parametreler

| Seçenek | Açıklama |
|---------|----------|
| `--from-manifest` | Zorunlu. Manifest yolu: `PLUME_SERVICES_MANIFEST_FILE` veya `~/.config/plume/services.yml` |
| `--dry-run` | Kurulum yapmaz; `services manifest show` effective satırları + bilgi logu |

## Çıktı / exit code

- **0**: Başarılı (veya dry-run).
- **2**: Manifest yok, mode ≠ native, ayrıcalık/prompt iptali, kurulum hatası.

## Örnekler

```bash
# Plan
plumectl services provision --from-manifest --dry-run

# Gerçek kurulum (macOS: TTY’de brew onayı; PLUME_NONINTERACTIVE=1 CI’da)
plumectl services provision --from-manifest
```

## Hata senaryoları

- Manifest yok → `init host` ile bootstrap edin.
- `database.engine: mysql` iken MariaDB formülü kurulmaz; `PLUME_MYSQL_ENABLED=true` olur.
- `mailpit.enabled: true` native’de paket kurmaz; docker moduna geçin veya Mailpit’i elle kurun.
- Kullanıcı interaktif prompt’ta iptal → exit 2.
- Windows native tam stack desteklenmez (host profili limited note).

## İlgili doküman

- [services-manifest.md](../operations/services-manifest.md)

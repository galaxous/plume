# CLI Output Contract (Adapter Readiness)

Bu dokuman, gelecekteki `plume-adapter` entegrasyonu icin CLI parse kurallarini tanimlar.

## Genel Kurallar

- Birincil komut ciktilari `stdout` (site id, tablolar, JSON, key=value)
- Ilerleme / log satirlari `stderr`: `[INFO]`, `[WARN]`, `[ERROR]` (D-157 — `site add` gibi parse edilen stdout kirlenmesin)
- Exit-code semasi:
  - `0`: success
  - `1`: runtime/internal error
  - `2`: validation/prereq/user-correctable error

## JSON Modu

Global `--json` flag'i aktiflestirir.

JSON desteklenen komutlar (minimum):

- `services supported`
- `services status`
- `prereq check`
- `site list`
- `site modes`
- `site check`

`site check --json` `data` alanlari (ek alanlar, geriye uyumlu):

- `effective_http_port`, `url_http`, `url_https` (cert varsa), `access_hint`, `tcc_risk` (boolean; macOS Desktop/Documents/Downloads path)
- `access_hint` doluysa ayni metin `warnings` dizisinde de yer alir
- `tcc_risk` true ise TCC metni `warnings` dizisinde de yer alir

- `status`
- `health`
- `monitor summary`

JSON temel sema:

```json
{
  "ok": true,
  "command": "services supported",
  "data": {},
  "warnings": [],
  "errors": []
}
```

Hata semasi:

```json
{
  "ok": false,
  "command": "prereq check",
  "errors": [
    {
      "code": "MISSING_DEPENDENCY",
      "message": "bash command not found",
      "hint": "Install bash and retry"
    }
  ]
}
```

`services supported --json` cikti semasi:

```json
{
  "ok": true,
  "command": "services supported",
  "data": {
    "mode": "native",
    "services": [
      { "name": "php", "enabled": true },
      { "name": "redis", "enabled": false }
    ]
  },
  "warnings": [],
  "errors": []
}
```

`services status --json` cikti semasi:

```json
{
  "ok": true,
  "command": "services status",
  "data": {
    "mode": "native",
    "services": [
      {
        "name": "php",
        "version": "8.4",
        "enabled": true,
        "running": true,
        "health": "healthy",
        "port": "9000",
        "desired": false,
        "resolved": false,
        "require_supervisor": false
      }
    ]
  },
  "warnings": [],
  "errors": []
}
```

## Native Adapter Contract Fields

- `enabled`: mode icindeki calisma niyeti
- `running`: runtime state
- `health`: `healthy|stopped|disabled|unknown`
- `port`: aktif host portu veya `-`
- `desired`: yalnizca `laradock-bridge` icin istenen service set'i
- `resolved`: yalnizca `laradock-bridge` icin dependency graph ile genisletilmis set
- `require_supervisor`: horizon icin supervisor bagimliligi gorunurlugu

Native modda `status` cikti formatinda:

- `web` satiri aktif driver'a gore `nginx|apache2|caddy` olarak yazilir
- `php-fpm` alias'i `php` satirina normalize edilir
- `workspace` alias'i `composer` satirina normalize edilir
- `laravel-horizon` alias'i `horizon` satirina normalize edilir

## Sozlesme Degisikligi Kurali

- Breaking contract degisikligi yapildiginda:
  - Bu dosya guncellenir
  - Decision log'a yeni karar eklenir
  - Migration notu yazilir

## Text Table Stabilization (Phase-10 Baseline)

`--json` disindaki parse-edilebilir text tablolarda:

- Header isimleri degistirilmemelidir.
- Kolon sirasi korunmalidir.
- Bos degerler `-` olarak yazilmalidir.

Bu kural su komutlar icin zorunludur:

- `services status`
- `status`
- `health`
- `site list`
- `monitor summary`

`site list` kolon sirasi:

- `ID`
- `SERVER`
- `PHP`
- `PORT`
- `HTTPS`
- `CERT`
- `STATUS`
- `DOMAINS`
- `PATH`

`PATH` kolonu her zaman son sutundadir; hizalama buyuk path degerlerinde de korunur.

`site modes` text cikti semasi:

- `ID`
- `MODE`
- `SERVER`
- `PHP`
- `STATUS`
- `PATH`

## Error Envelope

Validation kaynakli hatalar exit code `2` ile doner ve metin ciktisi su kalipta olur:

```text
[ERROR] <message>
```

Runtime/internal hatalar exit code `1` ile doner ve ayni on eki kullanir:

```text
[ERROR] <message>
```

Opsiyonel yonlendirme satirlari:

```text
[INFO] next: <command>
```

## deploy apply (text)

`deploy apply` basarili cikti sablonu:

```text
MODE              <mode>
DRY_RUN           false|true
STEP               STATUS
------------------ ------
1.pre-deploy-backup ok|skipped
2.doctor-check     ok|skipped
3.services-update  ok|skipped (no root)|skipped
4.monitor-summary  ok
OVERALL            OK
```

Dry-run modunda `OVERALL OK (dry-run)` satiri doner.

## project config show (text)

`project config show --path=...` ciktisi `key=value` satirlari (stdout); `--json` desteklenmez ve `adapter.json_critical_commands` listesinde degildir (Faz 16 MVP).

Ornek:

```text
manifest=/abs/project/plume.yml
mode=native
php_version=8.3
```

## services url / credentials (text)

Native-only key=value stdout; `--json` desteklenmez.

```text
url=http://127.0.0.1:8083
host=127.0.0.1
port=5432
```

Bkz. [docs/commands/services-url.md](../commands/services-url.md).

## services use (text)

Native-only key=value stdout; `--json` desteklenmez.

```text
engine=mariadb
enabled_mariadb=true
enabled_mysql=false
enabled_postgres=false
enabled_phpmyadmin=true
enabled_pgadmin=false
```

Bkz. [docs/commands/services-use.md](../commands/services-use.md).

# Plume Adapter Onboarding (Baseline)

Bu dokuman, gelecekteki `larasite-adapter`/`plume-adapter` paketinin Plume CLI ile entegrasyon baslangic sozlesmesini tanimlar.

## 1) Adapter Tasarim Prensibi

- Adapter, sistem komutlarini dogrudan degil `./plume.sh ...` uzerinden calistirir.
- Parse islemleri icin `--json` desteklenen komutlar tercih edilir.
- Kritik komutlarda `--yes` gerekliligi adapter tarafinda explicit olmalidir.

## 2) Minimum Komut Haritasi

- Mode/context:
  - `./plume.sh mode current`
  - `./plume.sh mode context`
  - `./plume.sh mode use native --force --yes --down-running` (laradock-bridge gecis guvenligi)
  - `./plume.sh mode path get <mode>`
- Site lifecycle:
  - `./plume.sh site list --json`
  - `./plume.sh site check <id> --json`
  - `./plume.sh site add ...`
  - `./plume.sh site update ...`
  - `./plume.sh site remove <id>`
- Service/ops:
  - `./plume.sh services status --json`
  - `./plume.sh status --json`
  - `./plume.sh health --json`
  - `./plume.sh monitor summary --json`

## 3) Exit Code Sozlesmesi

- `0`: basarili
- `1`: runtime/internal hata
- `2`: validation/prereq/kullanici duzeltilebilir hata

Adapter tarafinda `2` kodlari exception yerine kullaniciya duzeltme akisi olarak yansitilmalidir.

## 4) Critical Command Guard

Asagidaki komutlar `--yes` olmadan bloklanabilir:

- `mode use --force`
- `mode path set|clear --force`
- `services update`
- `services workspace reinit`
- `deploy rollback|failback` (dry-run haric)
- `backup restore`

Adapter UI/API seviyesinde "confirm" davranisi bu komutlara map edilmelidir.

## 5) State & Audit Kaynaklari

- State DB:
  - `~/.config/plume/state/plume-state.db` (veya `PLUME_STATE_DIR`)
- Runtime events:
  - `./plume.sh monitor events --limit=100`

Adapter, olay akisinda `critical.*`, `deploy.*`, `security.*`, `ops.*` event isimlerini filtreleyebilir.

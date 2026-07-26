# Documentation Strategy (Full Set)

## Hedef

Plume'in tum komutlarini tane tane aciklayan, server operasyonunda referans alinabilen ve gelecekteki `plume-adapter` paketine hizli onboarding saglayan bir dokumantasyon seti.

## Yapı

- `docs/commands/`: Komut bazli kullanim
- `docs/contracts/`: Parse-edilebilir cikti sozlesmeleri
- `docs/operations/`: Runbook ve faz-gate checklist
- `docs/operations/naming-policy.md`: brand/cli/repo/package isimlendirme standardi

## Command Doc Zorunlu Basliklari

1. Amac
2. Kullanim
3. Parametreler
4. Cikti / Exit Codes
5. Ornekler
6. Hata Senaryolari

## Guncelleme Kurali

- Kod degisince dokuman da degisir (tek degisiklik seti)
- Yeni komut eklendiginde ayni anda `docs/commands/<command>.md` eklenir
- Cikti semasi degisirse `docs/contracts/cli-output-contract.md` guncellenir

## Adapter Hazirligi (Out of Scope ama planli)

- Komutlarin deterministic output vermesi
- Exit code standardizasyonu
- `--json` modunun sema stabilitesi

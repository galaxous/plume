# Plume Implementation Context

Bu klasor, Plume'in fazli gelistirme planini ve teknik karar baglamini saklar.
Amac:

- Gelecekte AI veya insan contributor'un "ne, neden, hangi sirayla" bilgisini hizli anlamasi
- 3 senaryolu mimarinin (native, docker-lite, laradock-bridge) tek kaynaktan izlenmesi
- Her faz sonunda kararlarin, risklerin ve acik kalan islerin kaydi
- Moduler shell import duzeni ile gelistirme surecinin bolunebilir olmasi

## Dosyalar

- `phase-tracker.md`: tum fazlarin tek ekrandan takip tablosu (master board)
- `01-phased-plan.md`: Faz bazli roadmap
- `02-architecture.md`: Hedef mimari ve moduller
- `03-config-yaml-draft.md`: Konfigurasyon (lokal + production) YAML sozlesmesi taslagi
- `04-operations-observability.md`: Log, health-check, monitoring plani
- `05-decision-log.md`: Mimari karar gunlugu (ADR-lite)
- `06-prerequisites-matrix.md`: macOS/Linux core dependency kontrol matrisi
- `07-site-onboarding-and-obstacles.md`: site ekleme UX'i, registry modeli ve riskler
- `08-documentation-strategy.md`: full docs seti ve dokumantasyon zorunlulugu
- `09-answer-driven-constraints.md`: kullanici cevaplariyla netlesen zorunlu gereksinimler
- `10-herd-parity-and-beyond.md`: herd parity + beyond kapsam checklisti
- `11-status-2026-03-24.md`: bugun itibariyla gercek readiness durumu ve mod bazli acik/kapali alanlar
- `12-quality-gate-report-2026-04-03.md`: phase-10 baseline matrix quality gate raporu
- `phases/phase-XX.md`: faz bazli ayrik implementation checklistleri
  - aktif alt teslim notu:
    - `phases/phase-08a-laradock-bridge-runtime-parity.md`

## Calisma Kurali

Her yeni gelistirmede:

1. `phase-tracker.md` icinde ilgili faz satirini guncelle
2. `phases/phase-XX.md` dosyasinda ilgili checklist maddelerini isaretle
3. Alinan yeni teknik karari `05-decision-log.md` dosyasina ekle
4. Eger config sozlesmesi degisirse `03-config-yaml-draft.md` dosyasini revize et
5. Ilgili komut/operasyon dokumanlarini `docs/` altinda guncelle

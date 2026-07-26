# AGENTS Instructions (Project Local)

Bu proje icin AI/agent calisma kurallari:

1. Dokumantasyon zorunludur.
- Her kod degisikliginde ilgili dokuman dosyalari ayni PR/degisiklikte guncellenmelidir.
- Kod degisikligi yapilip dokuman guncellenmediyse is eksik kabul edilir.

2. Komutlar dokumante edilmelidir.
- Yeni eklenen her `plumectl` komutu icin `docs/commands/` altinda ayri dokuman olmalidir.
- Komut dokumani su basliklari icermelidir:
  - amac
  - kullanim
  - parametreler
  - cikti/exit-code
  - ornekler
  - hata senaryolari

3. Faz-gate disiplini zorunludur.
- Bir faz tamamlanmadan sonraki faza gecilmez.
- Faz tamamlama kriteri: test + dokumantasyon + karar kaydi.

4. Adapter-readiness dusunulmelidir.
- CLI ciktilari mumkun oldugunca stabil ve parse-edilebilir formatta tasarlanmalidir.
- `docs/contracts/` altindaki sozlesmeler her degisiklikte kontrol edilmelidir.

5. Smoke testler ve AI gelistirme
- PR oncesi varsayilan dogrulama: `./tests/run_smoke_suite.sh --release` (CI: `--ci`).
- Smoke scriptleri hermetik olmalidir (gecici HOME/PLUME_STATE_DIR; gercek `~/.config/plume` kullanilmaz).
- Test/shell patternleri: mock brew PATH, pipefail+grep, nginx strict env — bkz. asagidaki rehber.
- Yeni AI oturumlari icin session bootstrap ve tam strateji: [docs/operations/ai-assisted-development.md](docs/operations/ai-assisted-development.md).

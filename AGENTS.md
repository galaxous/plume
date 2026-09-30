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

6. Repo ve urun kimligi
- Urun: Plume; resmi CLI: `plumectl`; yerel wrapper: `./plume.sh`.
- GitHub: [galaxous/plume](https://github.com/galaxous/plume) (yerel klasor adi ornegin `larasite` olabilir).
- Kullanici state: `~/.config/plume` — smoke/testlerde ASLA kullanma (hermetik `HOME` / `PLUME_STATE_DIR`).

7. Konfigurasyon katmanlari
- Stack manifest: `~/.config/plume/services.yml` (D-103/D-104) — bkz. [docs/operations/services-manifest.md](docs/operations/services-manifest.md).
- Ortam: `~/.config/plume/.env` (`.env` manifest uzerinde kazanir).
- Makine profili: `host.env` (TCC/path; servis enable toggle degil).
- Proje: `plume.yml` MVP (Faz 16, D-117) — [docs/operations/project-plume-yml.md](docs/operations/project-plume-yml.md); genis schema / registry sync stretch backlog.

8. Yeni faz / yeni agent oturumu
- Baslangic okuma: [implementation/phase-tracker.md](implementation/phase-tracker.md), en guncel `implementation/11-status-*.md`.
- Faz 1-23 tamamlandi (Faz 7 beta-frozen); yeni ozellik = yeni `implementation/phases/phase-NN.md` + phase-tracker satiri.
- Faz kapanisi: checklist `[x]`, [implementation/05-decision-log.md](implementation/05-decision-log.md) (D-xxx), ilgili `docs/commands/` + `docs/contracts/`, `./tests/run_smoke_suite.sh --release`.
- Session bootstrap: [docs/operations/ai-assisted-development.md](docs/operations/ai-assisted-development.md).
- Urun backlog: [implementation/future-roadmap.md](implementation/future-roadmap.md); son kapanis: [implementation/11-status-2026-08-30.md](implementation/11-status-2026-08-30.md); kaynak: [phase-15-backlog-plume-yml-dockerlite.md](implementation/phases/phase-15-backlog-plume-yml-dockerlite.md) (D-089).
- Aktif faz yok; sonraki aday P2 meilisearch/minio. Faz 27–28 (Composer/Node + Release Homebrew/Packagist) kapandi.
- Git: kullanici `.env` / gizli dosya commit etme; commit yalnizca kullanici istediginde.

9. Native stack — OS matrisi (Phase 17+)
- Oncelik: **macOS** (Homebrew) ve **Linux** (apt, dnf); Windows native tam stack desteklenmez.
- Her yeni native servis PR: [docs/operations/native-stack-os-matrix.md](docs/operations/native-stack-os-matrix.md) satiri + mock smoke + `docs/commands/` guncellemesi zorunlu.
- macOS host kurulum: TCC/brew onay — [docs/operations/macos-permissions.md](docs/operations/macos-permissions.md).
- Linux smoke: mock `apt-get`/`dnf` + sahte `systemctl` (gercek `~/.config/plume` kullanma).

# Answer-Driven Constraints (2026-03-06)

Bu dosya, kullanici cevaplariyla netlesen zorunlu tasarim kararlarini toplar.

1. Yetki modeli
- Kurulum/guncelleme gibi sistem degisiklikleri sudo/root ile calisir.
- Runtime operasyonlar (start/stop/status/logs/health) root zorunlulugu olmadan calisabilmelidir.

2. TLS
- Sertifika destegi zorunlu.
- Gerekirse docker-lite ortaminda cert helper container kullanilabilir.

3. DNS
- Simdilik DNS yonetimi scope disi.
- Ileri faz/backlog icin planlanacak.

4. Cok kullanici/cok ekip
- Cok ekipli senaryo var; website registry disinda proje yetki modeli de ileride planlanacak.

5. Secrets
- Secret yonetimi zorunlu.

6. Rollback
- Fail durumunda otomatik geri alma senaryosu zorunlu.

7. Backup/Restore
- Opsiyonel olarak config + DB backup kapsami planlanacak.

8. Firewall/OS Security
- Firewall ve OS security kontrolleri zorunlu.

9. Docker-lite parity
- Native'deki cogunluk servis docker-lite mode'da da desteklenmeli.

10. Versioning/Updates
- Pinned version destegi ve auto-update opsiyonu olacak.

11. JSON output
- Tum komutlar degil, sadece kritik komutlarda JSON garanti edilecek.

12. Testing
- Faz kapanisinda tam E2E beklentisi var.

13. Horizon process manager
- Laravel Horizon icin supervisor gereksinimi atlanmayacak.

14. Service versions + PHP aliases
- Servislerde custom version secimi olacak.
- Tum PHP surumleri desteklenecek, default `php` ve versioned aliaslar yonetilecek.

15. Naming/collision policy
- Product adi `Plume` olacak.
- Linux util cakismasini azaltmak icin resmi binary `plumectl` olacak.
- `plume` opsiyonel shell alias olarak kalacak.

16. Herd parity + beyond
- Local + production'da Herd parity hedeflenirken deploy/rollback/observability gibi ekstra kabiliyetler zorunlu.

17. Laravel lifecycle completeness
- Bootstrap, runtime, deploy, backup, rollback ve incident adimlari planlarda eksiksiz yer alacak.

18. Minimal default services
- Default true yalnizca: php, composer, mariadb, nginx.
- Diger servisler default false olacak.
- Sonradan true olan servisler `services update` ile otomatik install+start edilmeli.

19. Unified env contract
- Tum servis/config degiskenleri `.env` uzerinden akmali.
- `.env.example` ortak + mode-ozel degiskenleri birlikte icermeli.

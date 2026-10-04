# Answer-Driven Constraints (2026-03-06)

This file collects mandatory design decisions clarified by user answers.

1. Privilege model
- System-changing steps such as install/update run with sudo/root.
- Runtime operations (start/stop/status/logs/health) must work without a root requirement.

2. TLS
- Certificate support is mandatory.
- If needed, a cert helper container may be used in docker-lite.

3. DNS
- DNS management is out of scope for now.
- It will be planned for a later phase/backlog.

4. Multi-user/multi-team
- Multi-team scenarios exist; beyond the website registry, a project privilege model will also be planned later.

5. Secrets
- Secret management is mandatory.

6. Rollback
- An automatic revert scenario on failure is mandatory.

7. Backup/Restore
- Optional config + DB backup scope will be planned.

8. Firewall/OS Security
- Firewall and OS security checks are mandatory.

9. Docker-lite parity
- Most services available in native must also be supported in docker-lite mode.

10. Versioning/Updates
- Pinned version support and an auto-update option will exist.

11. JSON output
- JSON is guaranteed only for critical commands, not all commands.

12. Testing
- Full E2E is expected at phase closure.

13. Horizon process manager
- The supervisor requirement for Laravel Horizon will not be skipped.

14. Service versions + PHP aliases
- Custom version selection will exist for services.
- All PHP versions will be supported; default `php` and versioned aliases will be managed.

15. Naming/collision policy
- Product name will be `Plume`.
- Official binary will be `plumectl` to reduce Linux util collision.
- `plume` remains an optional shell alias.

16. Herd parity + beyond
- While targeting Herd parity for local + production, extra capabilities such as deploy/rollback/observability are mandatory.

17. Laravel lifecycle completeness
- Bootstrap, runtime, deploy, backup, rollback, and incident steps will be fully covered in the plans.

18. Minimal default services
- Default true only for: php, composer, mariadb, nginx.
- Other services will be default false.
- Services flipped to true later must be auto installed+started via `services update`.

19. Unified env contract
- All service/config variables should flow through `.env`.
- `.env.example` should include both shared and mode-specific variables.

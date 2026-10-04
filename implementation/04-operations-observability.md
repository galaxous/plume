# Operations & Observability Plan

## Operations Commands (Target)

- `plumectl status`: Instant status of mode + services
- `plumectl health`: Health-check report
- `plumectl logs`: Access to service logs
- `plumectl monitor summary`: Summary telemetry
- `plumectl doctor --deep`: Config + port + process + dependency analysis

## Health-Check Model

- Types:
  - Is the port open
  - Does the HTTP endpoint respond
  - CLI probe (example: `redis-cli ping`)
- States:
  - `healthy`
  - `degraded`
  - `down`
- Output:
  - JSON and human-readable summary

## Log Strategy

- Location:
  - Local: `~/.config/plume/logs`
  - Server: `/var/log/plume`
- Rotation:
  - Size-based (example 10MB x 5)
- Sources by mode:
  - native: system service logs + plumectl action log
  - docker-lite: container logs + plumectl action log
  - laradock-bridge: docker compose logs + bridge action log

## Monitoring Scope (Initial)

- Service uptime
- Last 5 errors
- Port conflict events
- Last deploy/upgrade trail
- Laravel runtime metrics:
  - queue backlog/processing rate
  - failed jobs count
  - horizon status
  - scheduler last-run trail
  - deploy health gate result

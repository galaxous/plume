# Site Onboarding & Obstacles (Planning)

## Purpose

Add any website/Laravel project to a web server on the system with a single command:

- Take path
- Take domain
- Choose server (nginx/apache2/caddy)
- Write config + activate + check

## Target UX

- `plumectl site add`
  - Collects all information via interactive prompt
- `plumectl site add --path=/abs/path --domain=myapp.test --server=nginx`
  - Non-interactive for CI/automation

## Registry Model

- Site records are kept in Plume's central directory
- Separate file per site: `<site-id>.website.yaml`
- Global index: `index.yaml`
- `site-id` is generated deterministically (`slug + short-hash`)

Example site record:

```yaml
id: myapp-a1b2c3
name: myapp
project_path: /Users/dev/Sites/myapp
document_root: /Users/dev/Sites/myapp/public
server: nginx
domains:
  - myapp.test
  - api.myapp.test
mode: native
status: enabled
```

## Preventing CWD Confusion

- Regardless of which directory the command runs from, the registry is the source of truth
- If a relative path is given:
  - reject when `path_policy=absolute-only`
  - convert to absolute relative to the working dir when `path_policy=resolve-relative`
- Always write an absolute path into the record

## Likely Obstacles and Mitigations

1. Path invalid or moved
- Obstacle: registry record goes stale
- Mitigation: `site check` should verify path existence and web root

2. Domain conflict
- Obstacle: same domain is bound to more than one site
- Mitigation: domain uniqueness check during `site add` + required override flag

3. Server config drift
- Obstacle: registry and nginx/apache/caddy config diverge
- Mitigation: `site doctor` reports registry->config reconcile

4. Permission/sudo problem
- Obstacle: writing `/etc` or server config fails
- Mitigation: permission preflight before write + clear action message

5. Different server semantics
- Obstacle: nginx/apache2/caddy config structures differ
- Mitigation: server-specific template adapters (`sites_nginx`, `sites_apache`, `sites_caddy`)

6. Non-Laravel projects
- Obstacle: assumptions break when `public/` is missing
- Mitigation: custom `document_root` option in the prompt

## Phasing

- Phase 1:
  - Registry + `site add/list/remove/check` (native)
  - nginx template
- Phase 2:
  - docker-lite compatible site publish
- Phase 3:
  - laradock bridge site sync
- Phase 4+:
  - apache2/caddy template parity

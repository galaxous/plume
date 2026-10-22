# GitHub Pages: galaxous org site + custom domain checklist

Use GitHub Pages as a **static host** (HTML/CSS/JS only — no PHP/Laravel backends).  
This runbook covers:

1. Organization landing (`galaxous.com` → org site)
2. Product site for Plume (docs + optional landing) — already at [galaxous.github.io/plume](https://galaxous.github.io/plume/)
3. GoDaddy DNS → GitHub

Official GitHub docs: [Configuring a custom domain for GitHub Pages](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site).

---

## Target architecture

| Role | Repository | Default URL | Suggested custom domain |
|------|------------|-------------|-------------------------|
| Org landing | `galaxous/galaxous.github.io` | `https://galaxous.github.io` | `https://galaxous.com` (+ `www`) |
| Plume docs (+ landing) | `galaxous/plume` (this repo, `docs/`) | `https://galaxous.github.io/plume/` | `https://docs.galaxous.com` or `https://plume.galaxous.com` |

```text
galaxous.com          →  org products / about
docs.galaxous.com     →  Plume VitePress (or plume.galaxous.com)
github.com/galaxous/* →  source of truth
```

**Eligibility:** Pages works on **public** repos (or private with a plan that includes Pages).  
Plume is public and already deploys via `.github/workflows/docs.yml`.

---

## A. Org site (`galaxous.github.io`)

### A1. Create the repo

- [ ] Under org **galaxous**, create a **public** repository named exactly: `galaxous.github.io`
- [ ] Default branch: `main`
- [ ] Add a short README: “Galaxous organization site (GitHub Pages)”

### A2. Minimal site content

Pick one:

- **Simple:** `index.html` + CSS in repo root (no build)
- **VitePress / Astro / etc.:** build in GitHub Actions, publish `dist/` (same pattern as Plume `docs.yml`)

Minimum homepage content:

- [ ] Org name + one-line mission
- [ ] Product cards (at least Plume → link to docs URL)
- [ ] Links: GitHub org, contact / Twitter / email as needed

### A3. Enable Pages (org site)

- [ ] Repo → **Settings → Pages**
- [ ] Source: **GitHub Actions** (preferred) *or* Deploy from branch `main` / `/` for a pure static site
- [ ] Confirm site loads: `https://galaxous.github.io`
- [ ] Wait a few minutes after first deploy if you still see 404

### A4. Optional: Actions workflow (static)

If using branch deploy, skip. If using Actions, mirror Plume:

- [ ] Workflow builds (or copies) site to an artifact
- [ ] Job uses `actions/upload-pages-artifact` + `actions/deploy-pages`
- [ ] `permissions: pages: write` + `id-token: write`

---

## B. Plume product site (docs + landing)

Already in place:

- VitePress under `docs/`
- Workflow: `.github/workflows/docs.yml`
- Live: [https://galaxous.github.io/plume/](https://galaxous.github.io/plume/)
- `base: '/plume/'` in `docs/.vitepress/config.mjs` (required for project Pages path)

### B1. Landing + docs in one site (recommended)

- [ ] Treat `docs/index.md` as the **product landing** (hero, value props, CTA → Getting started)
- [ ] Keep deep docs under `guide/`, `commands/`, `operations/`
- [ ] Org site only links here — no second Plume marketing host required

### B2. If you later use a custom domain on Plume

When the site is served at the **apex of a subdomain** (e.g. `docs.galaxous.com`), change VitePress base:

- [ ] Set `base: '/'` (or `VITEPRESS_BASE=/` in the docs workflow build step)
- [ ] Redeploy and confirm assets load (no `/plume/assets/...` 404s)
- [ ] Keep project URL `galaxous.github.io/plume` working **or** accept redirect-only from GitHub path (GitHub redirects custom domain traffic; path URL may still work with old base — prefer one canonical URL)

---

## C. GoDaddy DNS → GitHub (org apex: `galaxous.com`)

Do this **after** the org Pages site responds on `https://galaxous.github.io`.

### C1. GitHub side (custom domain)

On `galaxous/galaxous.github.io`:

- [ ] Settings → Pages → **Custom domain**: `galaxous.com`
- [ ] Save (GitHub may create/commit a `CNAME` file — keep it in the repo)
- [ ] After DNS verifies: enable **Enforce HTTPS**

Also add `www` if you want both:

- [ ] Custom domain can be set to apex; then add DNS for `www` (below) and optionally set www → apex redirect in GoDaddy or serve both (GitHub documents www + apex patterns)

### C2. GoDaddy DNS records

In GoDaddy → Domain → DNS for `galaxous.com`:

**Apex (`galaxous.com`) — A records** (GitHub Pages IPs; confirm against current [GitHub docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site) if they change):

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `@` | `185.199.108.153` | 600 / 1 hour |
| A | `@` | `185.199.109.153` | 600 / 1 hour |
| A | `@` | `185.199.110.153` | 600 / 1 hour |
| A | `@` | `185.199.111.153` | 600 / 1 hour |

**www — CNAME:**

| Type | Name | Value | TTL |
|------|------|-------|-----|
| CNAME | `www` | `galaxous.github.io` | 600 / 1 hour |

- [ ] Remove conflicting A/CNAME/forwarding records GoDaddy added by default (parked page, “Domain Forwarding”, old A records)
- [ ] Do **not** put a CNAME on `@` unless GoDaddy explicitly supports ALIAS/ANAME for apex (standard CNAME on apex is invalid)

### C3. Verify

- [ ] `dig galaxous.com +short` → GitHub A IPs
- [ ] `dig www.galaxous.com +short` → `galaxous.github.io` (and then A IPs)
- [ ] GitHub Pages settings show domain **DNS check successful**
- [ ] `https://galaxous.com` and `https://www.galaxous.com` load (HTTPS may take up to ~1 hour after DNS)
- [ ] Hard-refresh browser / try private window (CDN cache)

---

## D. Optional: Plume subdomain (`docs.galaxous.com`)

On **`galaxous/plume`** (not the org site repo):

### D1. DNS (GoDaddy)

| Type | Name | Value |
|------|------|-------|
| CNAME | `docs` | `galaxous.github.io` |

(or `plume` → `galaxous.github.io` if you prefer `plume.galaxous.com`)

### D2. GitHub

- [ ] `galaxous/plume` → Settings → Pages → Custom domain: `docs.galaxous.com`
- [ ] Enforce HTTPS after verification
- [ ] Set VitePress `base: '/'` and redeploy (see B2)
- [ ] Update org landing + README links to the canonical docs URL

---

## E. What GitHub Pages cannot do

- Server-side apps (Laravel, Spring, Node API)
- Private env secrets in the **published** site (anything in the built HTML is public)
- Reliable “app server” features (sessions, DB). Use a real host (VPS, Fly, Railway, etc.) for backends; keep marketing/docs on Pages.

---

## F. Operator checklist (copy/paste)

```text
[ ] galaxous/galaxous.github.io public repo exists
[ ] Org site live on https://galaxous.github.io
[ ] GoDaddy A(@) ×4 + CNAME(www) → galaxous.github.io
[ ] Custom domain galaxous.com verified + HTTPS
[ ] Plume docs still live (github.io/plume and/or docs.galaxous.com)
[ ] Org homepage links to Plume docs
[ ] Canonical URLs documented in READMEs
```

---

## Related

- Plume docs site: [docs/README.md](../README.md)
- Deploy workflow: `.github/workflows/docs.yml`
- VitePress config: `docs/.vitepress/config.mjs` (`base` for project vs custom domain)

import { defineConfig } from 'vitepress'

// Plume docs site — content stays under docs/{guide,commands,operations,contracts}
// so AGENTS.md / smoke paths keep working.

// GitHub Pages project site: https://galaxous.github.io/plume/
// Override locally: VITEPRESS_BASE=/ npm run docs:dev
const base = process.env.VITEPRESS_BASE || '/plume/'

export default defineConfig({
  title: 'Plume',
  description: 'Laravel local ops CLI — native, docker-lite, laradock-bridge',
  base,
  cleanUrls: true,
  lastUpdated: true,
  // Markdown still links to repo-root paths (VERSION, AGENTS, implementation/, packaging/).
  ignoreDeadLinks: [
    /^https?:\/\/localhost/,
    /^\.\.\/\.\.\//,
    /\/implementation\//,
    /\/packaging\//,
    /\/lib\//,
    /\/templates\//,
    /AGENTS/,
    /VERSION$/,
  ],

  themeConfig: {
    logo: undefined,
    siteTitle: 'Plume',
    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Commands', link: '/commands/README' },
      { text: 'Operations', link: '/operations/README' },
      { text: 'Contracts', link: '/contracts/cli-output-contract' },
      {
        text: 'GitHub',
        link: 'https://github.com/galaxous/plume',
      },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: 'Getting started', link: '/guide/getting-started' },
            { text: 'Install', link: '/guide/install' },
            { text: 'First-run onboarding', link: '/guide/first-run' },
            { text: 'macOS permissions', link: '/guide/macos-permissions' },
          ],
        },
      ],
      '/commands/': [
        {
          text: 'Commands',
          items: [
            { text: 'Index', link: '/commands/README' },
            { text: 'Global flags', link: '/commands/global' },
            { text: 'version', link: '/commands/version' },
            { text: 'mode', link: '/commands/mode' },
            { text: 'env', link: '/commands/env' },
            { text: 'prereq', link: '/commands/prereq' },
            { text: 'init', link: '/commands/init' },
            { text: 'init host', link: '/commands/init-host' },
            { text: 'init onboarding', link: '/commands/init-onboarding' },
            { text: 'init permissions', link: '/commands/init-permissions' },
            { text: 'site', link: '/commands/site' },
            { text: 'php', link: '/commands/php' },
            { text: 'project', link: '/commands/project' },
            { text: 'project config', link: '/commands/project-config' },
            { text: 'workspace', link: '/commands/workspace' },
            { text: 'composer', link: '/commands/composer' },
            { text: 'npm', link: '/commands/npm' },
            { text: 'node', link: '/commands/node' },
            { text: 'schedule', link: '/commands/schedule' },
            { text: 'queue', link: '/commands/queue' },
            { text: 'deploy', link: '/commands/deploy' },
            { text: 'backup', link: '/commands/backup' },
            { text: 'security', link: '/commands/security' },
            { text: 'sync', link: '/commands/sync' },
            { text: 'status / health / logs', link: '/commands/status-health-logs' },
          ],
        },
        {
          text: 'Services',
          items: [
            { text: 'services', link: '/commands/services' },
            { text: 'services web', link: '/commands/services-web' },
            { text: 'services use', link: '/commands/services-use' },
            { text: 'services url', link: '/commands/services-url' },
            { text: 'services env', link: '/commands/services-env' },
            { text: 'services provision', link: '/commands/services-provision' },
            { text: 'services redis', link: '/commands/services-redis' },
            { text: 'services horizon', link: '/commands/services-horizon' },
            { text: 'services supervisor', link: '/commands/services-supervisor' },
            { text: 'services mailpit', link: '/commands/services-mailpit' },
            { text: 'services memcached', link: '/commands/services-memcached' },
            { text: 'services phpmyadmin', link: '/commands/services-phpmyadmin' },
            { text: 'services pgadmin', link: '/commands/services-pgadmin' },
          ],
        },
        {
          text: 'Doctor',
          items: [
            { text: 'doctor workspace', link: '/commands/doctor-workspace' },
            { text: 'doctor supervisor', link: '/commands/doctor-supervisor' },
          ],
        },
      ],
      '/operations/': [
        {
          text: 'Operations',
          items: [
            { text: 'Index', link: '/operations/README' },
            { text: 'Install (full)', link: '/operations/install' },
            { text: 'Release', link: '/operations/release' },
            { text: 'Release readiness', link: '/operations/release-readiness' },
            { text: 'Versioning & tags', link: '/operations/release-versioning-and-tags' },
            { text: 'First-run onboarding', link: '/operations/first-run-onboarding' },
            { text: 'Local dev (macOS)', link: '/operations/local-dev-macos' },
            { text: 'macOS permissions', link: '/operations/macos-permissions' },
            { text: 'Naming policy', link: '/operations/naming-policy' },
            { text: 'Env contract', link: '/operations/env-contract' },
            { text: 'Services manifest', link: '/operations/services-manifest' },
            { text: 'Native OS matrix', link: '/operations/native-stack-os-matrix' },
            { text: 'Native service contract', link: '/operations/native-service-contract' },
            { text: 'Service support matrix', link: '/operations/service-support-matrix' },
            { text: 'Laravel project lifecycle', link: '/operations/laravel-project-lifecycle' },
            { text: 'project plume.yml', link: '/operations/project-plume-yml' },
            { text: 'Docker-lite template', link: '/operations/docker-lite-template' },
            { text: 'Laradock-bridge workflows', link: '/operations/laradock-bridge-workflows' },
            { text: 'Site/service ops parity', link: '/operations/site-service-ops-parity-runbook' },
            { text: 'Backup / restore', link: '/operations/backup-restore-runbook' },
            { text: 'Incident triage', link: '/operations/incident-triage-runbook' },
            { text: 'Security ops baseline', link: '/operations/security-ops-baseline' },
            { text: 'Preflight security', link: '/operations/preflight-security' },
            { text: 'Adapter onboarding', link: '/operations/plume-adapter-onboarding' },
            { text: 'Phase-gate checklist', link: '/operations/phase-gate-checklist' },
            { text: 'AI-assisted development', link: '/operations/ai-assisted-development' },
          ],
        },
      ],
      '/contracts/': [
        {
          text: 'Contracts',
          items: [
            { text: 'CLI output contract', link: '/contracts/cli-output-contract' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/galaxous/plume' },
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Plume docs — VitePress',
      copyright: 'MIT · galaxous/plume',
    },

    editLink: {
      pattern: 'https://github.com/galaxous/plume/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },
  },
})

// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://herdr-orchestra.vercel.app',
  redirects: { '/docs/autopilot': '/docs/driving', '/docs': '/docs/introduction' },
  integrations: [
    starlight({
      title: 'herdr-orchestra',
      description: 'Orchestrate AI coding agents in Herdr: a lead plans, coders build in parallel on models that fit each task, a reviewer checks every diff, and you get one pull request.',
      // Share cards for docs pages, the same image as the landing pages.
      head: [
        { tag: 'meta', attrs: { property: 'og:image', content: 'https://herdr-orchestra.vercel.app/og.png' } },
        { tag: 'meta', attrs: { name: 'twitter:image', content: 'https://herdr-orchestra.vercel.app/og.png' } },
      ],
      logo: { src: './src/assets/mark.svg', replacesTitle: false },
      favicon: '/favicon.svg',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/arunnarangali/herdr-orchestra' },
      ],
      components: { Header: './src/components/DocsHeader.astro' },
      customCss: ['./src/styles/tokens.css', './src/styles/starlight.css'],
      sidebar: [
        { label: 'Home', link: '/' },
        {
          label: 'Getting started',
          items: [
            { label: 'Introduction', slug: 'docs/introduction' },
            { label: 'Installation', slug: 'docs/installation' },
            { label: 'Quick start', slug: 'docs/quick-start' },
          ],
        },
        {
          label: 'The workflow',
          items: [
            { label: 'How a run works', slug: 'docs/workflow' },
            { label: 'Writing a feature request', slug: 'docs/feature-request' },
            { label: 'The orchestration plan', slug: 'docs/planning' },
            { label: 'The orchestration run', slug: 'docs/driving' },
            { label: 'The lead and the event manager', slug: 'docs/lead' },
            { label: 'Models and tiers', slug: 'docs/models' },
            { label: 'The plan file', slug: 'docs/plan-file' },
            { label: 'Checks, reviews and fixes', slug: 'docs/reviews' },
            { label: 'Modes', slug: 'docs/modes' },
            { label: 'Git, commits and the PR', slug: 'docs/git' },
            { label: 'When a run needs you', slug: 'docs/when-it-stops' },
          ],
        },
        { label: 'Agents', items: [{ label: 'Agents and roles', slug: 'docs/agents' }] },
        {
          label: 'Reference',
          items: [
            { label: 'Commands', slug: 'docs/commands' },
            { label: 'Configuration', slug: 'docs/configuration' },
            { label: 'Files', slug: 'docs/files' },
          ],
        },
      ],
    }),
  ],
});

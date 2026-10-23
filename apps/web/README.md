# TokenBar website

The official TokenBar website. Today it is a single placeholder page; the real site is
a future milestone.

## Stack

- [Astro](https://astro.build) with TypeScript (strict), output as a fully static site.
- No UI framework, no CSS framework, no client-side JavaScript.
- No analytics, tracking, external fonts, or third-party scripts.

The site is independent of the macOS app: it does not need Xcode, and the macOS build
and release never touch this folder.

## Requirements

Node.js 22.23.4 or later (CI uses Node 24, see `.nvmrc`) and npm.

## Development

From this folder (`apps/web`):

```sh
npm ci            # install exact versions from package-lock.json
npm run dev       # dev server at http://localhost:4321
npm run check     # type-check .astro and .ts files
npm run build     # production build into dist/
npm run preview   # serve the built dist/ locally
```

Astro's CLI collects anonymous usage data by default. To opt out on your machine, run
`npx astro telemetry disable` or set `ASTRO_TELEMETRY_DISABLED=1` (CI does the latter).

## Output

`npm run build` writes plain static files (HTML and inlined CSS) to `apps/web/dist/`.
Any static host can serve that folder as-is; no adapter or server runtime is needed.
Hosting is not configured yet.

No environment variables or secrets are needed. Never commit `.env` files.

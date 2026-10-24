# TokenBar website

The official TokenBar website, served at <https://tokenbar.sh>. One static page that
explains the product, plus `/llms.txt`, `/llms.md`, `/robots.txt`, `/sitemap.xml` and a 404.

## Stack

- [Astro](https://astro.build) with TypeScript (strict), output as a fully static site.
- No UI framework and no CSS framework. All content is rendered to HTML at build time.
- A small amount of vanilla TypeScript for motion and interaction (about 7 KB gzipped).
  No animation library, no WebGL.
- Two self-hosted fonts from Fontsource (Latin subset, SIL Open Font License):
  Instrument Sans (variable, weight and width axes) and Instrument Serif (italic only).
  Replicas of the app's UI use the system font, like the app does.
- No analytics, tracking, cookies, external fonts, or third-party scripts. The page
  makes no requests to other origins; links to GitHub are plain links.

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

## Layout

```text
src/
├── config.ts            # canonical links, SEO title and description, requirements
├── data/
│   ├── sample.ts        # sample usage shown in every replica (always labeled)
│   └── roadmap.ts       # the roadmap section; mirrors docs/roadmap.md
├── components/          # one component per section, plus the app replicas
│   ├── StatusItem.astro # TokenBar's menu bar label
│   ├── Popover.astro    # TokenBar's popover
│   └── …
├── scripts/
│   ├── motion.ts        # scroll-progress scenes, reveals, magnetic buttons, tilt
│   └── popover.ts       # drives the popover replicas
├── layouts/BaseLayout.astro  # <head>: metadata, Open Graph, fonts, JSON-LD
└── pages/               # index, 404, sitemap.xml
public/                  # robots.txt, llms.txt, llms.md, og.png, icons
```

## Motion and accessibility

Every section is complete without JavaScript. An inline script in `<head>` adds two
classes before the first paint: `js`, and `motion` unless the visitor prefers reduced
motion. Pinned (sticky) scroll scenes, reveals and the roadmap path only exist under
`.motion`; without it the page is a regular static document. Pinned scenes run only at
1024 px and wider; smaller screens get a simpler flow. Animations use `transform` and
`opacity`, and scene scripts only run while their section is near the viewport.

## Keeping the facts in sync

The website, `public/llms.txt`, `public/llms.md`, the structured data in
`src/pages/index.astro`, the Open Graph text in `src/config.ts`, the root README and
`docs/roadmap.md` must say the same things. Review all of them whenever TokenBar
changes any of:

- supported providers or what each one shows,
- supported platforms (today: macOS available, Windows planned),
- major features,
- the privacy architecture,
- download or install behavior (today: unsigned and not notarized),
- the roadmap (`src/data/roadmap.ts` mirrors `docs/roadmap.md`).

`llms.txt` and `llms.md` are maintained by hand on purpose; there is no generator.

The download button always links to the latest GitHub release, so a new release needs
no website change unless the install steps change. The site URL lives in
`astro.config.mjs` (`site`) and is repeated as plain text in `public/robots.txt`,
`public/llms.txt` and `public/llms.md`.

`public/og.png` (1200 × 630) is rendered from an HTML mock-up; regenerate it if the
headline or icon changes. `src/assets/logos/*.svg` are converted from the app's PDF logos
in `apps/macos/TokenBarKit/Sources/TokenBarUI/Resources/Logos` and are only used to
identify each provider.

## Output

`npm run build` writes plain static files (HTML, CSS, JS, fonts, images) to
`apps/web/dist/`. Any static host can serve that folder as-is; no adapter or server
runtime is needed. Hosting is not configured yet.

No environment variables or secrets are needed. Never commit `.env` files.

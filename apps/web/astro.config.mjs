// @ts-check
import { defineConfig } from "astro/config";

// Static output only: `npm run build` writes plain HTML/CSS/JS to dist/, which any static
// host (e.g. Cloudflare Pages) can serve. No adapter, no server runtime.
export default defineConfig({
  // Production origin. Canonical URLs, Open Graph, the sitemap and structured data are built
  // from it. public/robots.txt, public/llms.txt and public/llms.md repeat it as plain text.
  site: "https://tokenbar.sh",
  output: "static",
  trailingSlash: "ignore",
  build: {
    format: "file",
  },
  devToolbar: { enabled: false },
});

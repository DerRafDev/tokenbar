// @ts-check
import { defineConfig } from "astro/config";

// Static output only: `npm run build` writes plain HTML/CSS to dist/, which any static
// host (e.g. Cloudflare Pages) can serve. No adapter, no server runtime.
export default defineConfig({
  output: "static",
});

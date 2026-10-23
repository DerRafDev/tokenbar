# README demo

Source for [`docs/assets/demo.gif`](../../docs/assets/demo.gif), the product demo in the
main README. It is a rendered animation, not a screen recording: [`index.html`](index.html)
draws a mock menu bar and popover with fixed sample numbers in a three.js scene, and
[`render.mjs`](render.mjs) captures it frame by frame in headless Chrome.

## Requirements

- macOS with Google Chrome installed (Playwright drives it via `channel: 'chrome'`)
- Node.js 18+ and npm
- ffmpeg (`brew install ffmpeg`)

## Regenerate the GIF

```sh
cd tools/demo
npm ci
npm run build
```

`npm run build` runs two steps:

1. `npm run render` writes 160 PNG frames (8 s at 20 fps, 1440×900) to `frames/`.
2. `npm run encode` turns them into a 720×450 looping GIF at `docs/assets/demo.gif`.

To check a few moments without rendering every frame, pass times in seconds; the frames
land in `previews/`:

```sh
node render.mjs 20 0.3,2.5,4.2,5.3,6.6
```

`frames/`, `previews/` and `node_modules/` are ignored by git.

## Assets

`assets/claude.png` and `assets/openai.png` are the app's provider logos, converted from
the PDFs in `apps/macos/TokenBarKit/Sources/TokenBarUI/Resources/Logos`:

```sh
L=../../apps/macos/TokenBarKit/Sources/TokenBarUI/Resources/Logos
for n in claude openai; do sips -s format png -Z 256 "$L/$n.pdf" --out "assets/$n.png"; done
```

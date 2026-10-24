// The site's whole animation system: a scroll-progress loop for pinned scenes, one-shot
// reveals, and a few pointer effects. No dependencies. Everything here is an enhancement:
// without JavaScript, or with Reduce Motion, the page is complete and static.

export const motionEnabled = (): boolean => document.documentElement.classList.contains("motion");

export const clamp = (x: number, a = 0, b = 1): number => Math.min(b, Math.max(a, x));
/** Progress of `x` through the range [a, b], clamped to 0…1. */
export const seg = (x: number, a: number, b: number): number => clamp((x - a) / (b - a));
export const lerp = (a: number, b: number, t: number): number => a + (b - a) * t;
export const easeOut = (t: number): number => 1 - Math.pow(1 - clamp(t), 4);
export const easeInOut = (t: number): number => {
  t = clamp(t);
  return t < 0.5 ? 8 * t ** 4 : 1 - Math.pow(-2 * t + 2, 4) / 2;
};

type SceneHandler = (progress: number, el: HTMLElement) => void;

interface Scene {
  el: HTMLElement;
  pass: boolean;
  handler: SceneHandler;
  active: boolean;
  /** Set when the scene leaves the viewport, so it settles at 0 or 1 once more. */
  flush: boolean;
  last: number;
}

const scenes: Scene[] = [];
let frame = 0;

/**
 * Calls `handler` with the scroll progress (0…1) of a pinned section: 0 when its top reaches
 * the top of the viewport, 1 when its bottom reaches the bottom. With `pass`, progress runs
 * instead from the moment the element enters at the bottom until it leaves at the top. Also
 * sets `--p` on the element, so CSS can follow the same value. Only runs while the element
 * is near the viewport.
 */
export function scene(el: HTMLElement | null, handler: SceneHandler, { pass = false } = {}): void {
  if (!el || !motionEnabled()) return;
  const s: Scene = { el, pass, handler, active: false, flush: false, last: -1 };
  scenes.push(s);
  observer.observe(el);
}

const observer =
  typeof IntersectionObserver === "undefined"
    ? (null as unknown as IntersectionObserver)
    : new IntersectionObserver(
        (entries) => {
          for (const entry of entries) {
            const s = scenes.find((x) => x.el === entry.target);
            if (!s) continue;
            s.active = entry.isIntersecting;
            s.flush = !entry.isIntersecting;
          }
          request();
        },
        { rootMargin: "25% 0px 25% 0px" },
      );

function tick(): void {
  frame = 0;
  const vh = window.innerHeight;
  for (const s of scenes) {
    if (!s.active && !s.flush) continue;
    s.flush = false;
    const rect = s.el.getBoundingClientRect();
    const p = s.pass
      ? clamp((vh - rect.top) / (vh + rect.height))
      : clamp(-rect.top / Math.max(1, rect.height - vh));
    if (Math.abs(p - s.last) < 0.0005) continue;
    s.last = p;
    s.el.style.setProperty("--p", p.toFixed(4));
    s.handler(p, s.el);
  }
}

export function request(): void {
  if (!frame) frame = requestAnimationFrame(tick);
}

window.addEventListener("scroll", request, { passive: true });
window.addEventListener("resize", () => {
  for (const s of scenes) s.last = -1;
  request();
});

/** Adds `is-in` once to [data-reveal] and [data-lines] elements as they enter the viewport. */
export function initReveals(): void {
  const targets = document.querySelectorAll<HTMLElement>("[data-reveal], [data-lines]");
  for (const el of document.querySelectorAll<HTMLElement>("[data-lines]")) {
    el.querySelectorAll<HTMLElement>(".line > span").forEach((span, i) => span.style.setProperty("--i", String(i)));
  }
  if (!motionEnabled() || typeof IntersectionObserver === "undefined") {
    targets.forEach((el) => el.classList.add("is-in"));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("is-in");
        io.unobserve(entry.target);
      }
    },
    { rootMargin: "0px 0px -12% 0px" },
  );
  targets.forEach((el) => io.observe(el));
}

const finePointer = (): boolean => matchMedia("(hover: hover) and (pointer: fine)").matches;

/** Buttons marked [data-magnetic] lean a few pixels toward the pointer. */
export function initMagnetic(): void {
  if (!motionEnabled() || !finePointer()) return;
  for (const el of document.querySelectorAll<HTMLElement>("[data-magnetic]")) {
    el.addEventListener("pointermove", (e) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left - r.width / 2) / r.width;
      const y = (e.clientY - r.top - r.height / 2) / r.height;
      el.style.setProperty("--mx", `${(x * 8).toFixed(2)}px`);
      el.style.setProperty("--my", `${(y * 6).toFixed(2)}px`);
    });
    el.addEventListener("pointerleave", () => {
      el.style.removeProperty("--mx");
      el.style.removeProperty("--my");
    });
  }
}

/**
 * Smoothed pointer position over the window, -1…1 on each axis, for subtle tilt effects.
 * Calls `onChange` from an animation frame while the value settles.
 */
export function pointerTilt(onChange: (x: number, y: number) => void): void {
  if (!motionEnabled() || !finePointer()) return;
  let tx = 0;
  let ty = 0;
  let x = 0;
  let y = 0;
  let raf = 0;
  const step = (): void => {
    x += (tx - x) * 0.08;
    y += (ty - y) * 0.08;
    onChange(x, y);
    raf = Math.abs(tx - x) + Math.abs(ty - y) > 0.001 ? requestAnimationFrame(step) : 0;
  };
  window.addEventListener(
    "pointermove",
    (e) => {
      tx = (e.clientX / window.innerWidth) * 2 - 1;
      ty = (e.clientY / window.innerHeight) * 2 - 1;
      if (!raf) raf = requestAnimationFrame(step);
    },
    { passive: true },
  );
}

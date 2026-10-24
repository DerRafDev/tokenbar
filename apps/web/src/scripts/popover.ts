// Drives the Popover.astro replicas: which provider is expanded, values, and the footer.
import type { ProviderId } from "../data/sample";

export interface PopoverControl {
  expand(id: ProviderId | null): void;
  set(id: ProviderId, limit: "session" | "weekly", used: number): void;
  setReset(id: ProviderId, limit: "session" | "weekly", text: string): void;
  updated(text: string, spinning?: boolean): void;
  /** Called after the visitor toggles a row with the mouse or keyboard. */
  onToggle?: (id: ProviderId | null) => void;
}

/** 70% and above draws attention, 90% and above is critical (UsageLevel in the app). */
export const level = (used: number): "normal" | "attention" | "critical" =>
  used >= 90 ? "critical" : used >= 70 ? "attention" : "normal";

export function popover(root: HTMLElement | null): PopoverControl | null {
  if (!root) return null;
  const rows = [...root.querySelectorAll<HTMLElement>(".prow")];
  const row = (id: ProviderId): HTMLElement | undefined => rows.find((r) => r.dataset.provider === id);
  let expanded: ProviderId | null = rows.find((r) => r.classList.contains("is-open"))?.dataset.provider as ProviderId;

  const control: PopoverControl = {
    expand(id) {
      if (id === expanded) return;
      expanded = id;
      for (const r of rows) {
        const open = r.dataset.provider === id;
        r.classList.toggle("is-open", open);
        r.querySelector("button")?.setAttribute("aria-expanded", String(open));
      }
    },
    set(id, limit, used) {
      const r = row(id);
      if (!r) return;
      const text = `${Math.floor(used)}%`;
      for (const el of r.querySelectorAll<HTMLElement>(`[data-v="${limit}"]`)) {
        if (el.textContent !== text) el.textContent = text;
        el.dataset.level = level(used);
      }
      const bar = r.querySelector<HTMLElement>(`[data-bar="${limit}"]`);
      if (bar) {
        bar.style.setProperty("--f", String(used / 100));
        bar.dataset.level = level(used);
      }
    },
    setReset(id, limit, text) {
      const el = row(id)?.querySelector<HTMLElement>(`[data-reset="${limit}"]`);
      if (el && el.textContent !== text) el.textContent = text;
    },
    updated(text, spinning = false) {
      const label = root.querySelector<HTMLElement>("[data-updated]");
      if (label && label.textContent !== text) label.textContent = text;
      root.querySelector("[data-spin]")?.classList.toggle("is-spinning", spinning);
    },
  };

  for (const r of rows) {
    const button = r.querySelector("button");
    button?.addEventListener("click", () => {
      const id = r.dataset.provider as ProviderId;
      const next = expanded === id ? null : id;
      control.expand(next);
      control.onToggle?.(next);
    });
  }
  return control;
}

// The public roadmap, from docs/roadmap.md. Keep both in sync. No dates: the order shows how
// settled each item is. "Candidates" are not commitments.

export type RoadmapState = "shipped" | "planned" | "exploring";

export interface Milestone {
  state: RoadmapState;
  label: string;
  title: string;
  version?: string;
  /** Platform availability shown as a tag. */
  platform?: string;
  text?: string;
  items?: { title: string; text?: string }[];
  /** Shown as a large word that emerges as the path reaches it. */
  spotlight?: boolean;
}

export const roadmap: Milestone[] = [
  {
    state: "shipped",
    label: "Shipped",
    version: "v0.1.0",
    title: "The beginning",
    platform: "macOS · Available now",
    text: "The first public release.",
    items: [
      { title: "Native menu bar app for macOS" },
      { title: "Claude and Codex, experimental" },
      { title: "Session and weekly limits with reset countdowns" },
      { title: "Three menu bar display modes" },
      { title: "Automatic refresh and open at login" },
      { title: "English and Portuguese (Brazil)" },
    ],
  },
  {
    state: "planned",
    label: "Planned",
    title: "Windows",
    spotlight: true,
    text: "A Windows version of TokenBar is being planned. There is no release date and no download yet.",
  },
  {
    state: "exploring",
    label: "After 0.1.0",
    title: "Candidates, not commitments",
    text: "Each one needs evidence that it works reliably before it is built.",
    items: [
      {
        title: "Developer ID signing and notarization",
        text: "Removes the first-launch Gatekeeper step and keeps Claude’s Keychain permission across updates. The release pipeline already supports it.",
      },
      { title: "Codex Keychain sign-in", text: "For Codex installations that keep their sign-in in the Keychain." },
      { title: "Clearer Codex errors", text: "Telling an expired sign-in apart from a workspace without Codex." },
      { title: "Refresh when the network comes back", text: "Today data stays marked outdated until the next scheduled refresh." },
      { title: "Automatic updates", text: "Would be the first request not made for a provider. Needs a privacy-preserving design." },
      { title: "More providers", text: "Only with a reliable, documented-enough data source." },
      { title: "Menu bar customization", text: "Driven by feedback from daily use." },
    ],
  },
];

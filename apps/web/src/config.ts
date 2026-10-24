// Canonical links and product facts used across the site. Keep them in sync with the
// README, docs/roadmap.md, public/llms.txt and public/llms.md (see the README in apps/web).

const repo = "https://github.com/DerRafDev/tokenbar";

export const links = {
  repo,
  // Always the newest release, so no page hardcodes a version to download.
  download: `${repo}/releases/latest`,
  releases: `${repo}/releases`,
  issues: `${repo}/issues`,
  newIssue: `${repo}/issues/new/choose`,
  providerRequest: `${repo}/issues/new?template=provider_request.yml`,
  security: `${repo}/security/advisories/new`,
  license: `${repo}/blob/main/LICENSE`,
  contributing: `${repo}/blob/main/CONTRIBUTING.md`,
  roadmap: `${repo}/blob/main/docs/roadmap.md`,
  providers: `${repo}/blob/main/docs/providers.md`,
  addingProvider: `${repo}/blob/main/docs/adding-a-provider.md`,
  architecture: `${repo}/blob/main/docs/architecture.md`,
} as const;

export const seo = {
  title: "AI Usage Limits in Your Menu Bar | TokenBar",
  description:
    "Track your AI usage limits from your menu bar. TokenBar is a free, native and open-source app that shows session and weekly limits and when they reset. Supports Claude and Codex. Available for macOS, with Windows planned.",
} as const;

export const requirements = "macOS 14 Sonoma or later · Apple silicon or Intel";

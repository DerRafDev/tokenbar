// Sample data for every TokenBar replica on the site. It matches the README demo
// (tools/demo) and is always labeled as sample data. Strings follow the app's formatter
// (UsageFormatter): "Resets at 5:10 PM (in 2h 18m)", "Session 42% · Week 18%".

export type ProviderId = "claude" | "codex";

export interface SampleLimit {
  id: "session" | "weekly";
  title: string;
  short: string;
  used: number;
  reset: string;
}

export interface SampleProvider {
  id: ProviderId;
  name: string;
  plan: string;
  logo: "claude" | "openai";
  limits: SampleLimit[];
}

export const sampleProviders: SampleProvider[] = [
  {
    id: "claude",
    name: "Claude",
    plan: "Max",
    logo: "claude",
    limits: [
      { id: "session", title: "Current session", short: "Session", used: 42, reset: "Resets at 5:10 PM (in 2h 18m)" },
      { id: "weekly", title: "Weekly", short: "Week", used: 18, reset: "Resets in 3d 4h (Sun, Oct 26 at 7:00 PM)" },
    ],
  },
  {
    id: "codex",
    name: "Codex",
    plan: "Plus",
    logo: "openai",
    limits: [
      { id: "session", title: "Current session", short: "Session", used: 12, reset: "Resets at 6:45 PM (in 3h 53m)" },
      { id: "weekly", title: "Weekly", short: "Week", used: 27, reset: "Resets in 5d 2h (Tue, Oct 28 at 4:52 PM)" },
    ],
  },
];

export const sampleLabel = "Sample data: Claude 42%, Codex 12%";

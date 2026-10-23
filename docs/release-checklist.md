# Release checklist

Run on a real Mac with the **release artifact** (the DMG from `scripts/release.sh` or the
draft GitHub Release), not an Xcode build. Quit any development copy of TokenBar first.
About 30 minutes, plus waiting for a session reset.

To start from a clean slate, quit TokenBar and run:

```sh
defaults delete io.github.derrafdev.TokenBar   # TokenBar's preferences only
```

## Install

- [ ] `shasum -a 256 -c SHA256SUMS.txt` passes.
- [ ] Opening the DMG shows TokenBar and an Applications shortcut, with the TokenBar icon.
- [ ] Drag to Applications. Finder and Launchpad show the TokenBar icon, with no gray tile behind it.
- [ ] First launch: signed build opens after the usual "downloaded from the internet" prompt;
      an `-unsigned` build needs *Privacy & Security › Open Anyway*.
- [ ] The menu bar shows the gauge icon. No Dock icon, no window.
- [ ] The popover says "No providers enabled". *Settings › Providers*: both disabled.
- [ ] Console.app (subsystem `io.github.derrafdev.TokenBar`) shows no refresh and no
      Keychain prompt appears before a provider is enabled.

## Claude

- [ ] Enable Claude: the experimental warning and what is read appear before it turns on.
- [ ] macOS asks for "Claude Code-credentials". **Deny** → "Access was not allowed", and no
      new prompt on the next scheduled refresh.
- [ ] Refresh manually → prompt again → **Always Allow** → usage appears.
- [ ] Session %, weekly % and reset times match Claude Code's `/usage`.
- [ ] Plan badge is correct (Pro/Max).

## Codex

- [ ] Enable Codex: warning appears, mentions Codex limits are not ChatGPT limits.
- [ ] No macOS prompt (Codex is a file). Usage appears.
- [ ] 5-hour and weekly % and reset times match Codex's `/status`.

## Everyday use

- [ ] Refresh button: "Updating…", then "Updated just now".
- [ ] Menu bar modes Providers / Minimal / Detailed each look right with both providers;
      hiding one provider from the menu bar works.
- [ ] A session reset: after the reset time passes, the row says "Reset due, updating soon",
      then shows the new usage after the next refresh.
- [ ] Weekly reset shows a date and countdown ("Resets in 2d 14h (…)").
- [ ] Sleep the Mac for 10+ minutes, wake: within about a minute the popover shows fresh
      data ("Updated just now"), not an outdated mark.
- [ ] Turn Wi-Fi off, refresh: last values stay with an outdated mark; expanded, the provider
      says "Updated … You're offline." Wi-Fi back on: recovers by the next refresh.
- [ ] Disable a provider: it disappears from the menu bar and popover.

## Appearance and language

- [ ] Light mode and dark mode: popover text, bars, badges, dividers and the menu bar
      label are legible; Settings looks native.
- [ ] Language set to Portuguese (Brazil) (*System Settings › General › Language & Region*
      or per app): popover, Settings, warnings and reset times are translated and not truncated.
- [ ] English: the same.

## Login and relaunch

- [ ] *Settings › General › Open at login* on. It appears in *System Settings › General ›
      Login Items*. Log out and in: TokenBar starts.
- [ ] Turn it off: removed from Login Items.
- [ ] Quit from the popover's gear menu and reopen: enabled providers, menu bar mode and
      refresh interval are kept, and Claude does not prompt again.

## Before publishing

- [ ] README screenshot is current and shows no email, account name, or private window.
- [ ] Draft release: notes are right, artifacts are `TokenBar-<version>.dmg`, `.zip` and
      `SHA256SUMS.txt`, and the version matches the tag.

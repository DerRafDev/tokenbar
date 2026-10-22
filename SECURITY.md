# Security Policy

TokenBar reads credentials that other apps (Claude Code, Codex) store on your Mac,
so security reports are taken seriously.

## Reporting a vulnerability

**Do not open a public issue.** Use
[GitHub private vulnerability reporting](https://github.com/DerRafDev/tokenbar/security/advisories/new).
You should receive a response within 7 days.

Please include the TokenBar version, macOS version, steps to reproduce, and impact.

## Supported versions

Only the latest release receives security fixes while TokenBar is in `0.x`.

## What TokenBar promises

- Usage data stays on your Mac. There is no TokenBar server.
- Credentials owned by other apps are read when a refresh happens and are never
  copied, refreshed, transmitted anywhere except to the provider they belong to,
  or written to disk.
- Credentials TokenBar stores itself live only in the macOS Keychain.
- Tokens, cookies, account identifiers, authenticated URLs, and response bodies
  are never logged.

A violation of any of these is a security bug.

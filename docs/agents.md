# Agent alerts (experimental, Debug only)

TokenBar can show when a Claude Code session is waiting for an answer from you. While one is,
the menu bar shows an amber dot and `Claude · N` instead of usage (`N` alone in Minimal mode or
when several providers wait), and the popover opens on **Agents › Waiting for you**, one row per
session ("Claude Code · project", "Terminal · Waiting for an answer · now"). When the last
question is answered, the menu bar returns to the usage mode you chose.

**Status:** prototype. It exists only in Debug builds and only runs when the app is launched with
`TOKENBAR_AGENT_HOOKS=1`. Release builds contain no listener, no Apple Events entitlement, and
install no hooks. To try it, follow [testing-agent-alerts.md](testing-agent-alerts.md).

## Validated and missing

| | Status |
|---|---|
| Structured questions from Claude Code (`AskUserQuestion`) | **Validated** with real sessions (Claude Code 2.1.116 and 2.1.319) |
| Counter, one per session; `2 → 1 → usage` as questions are answered | **Validated** live in the menu bar |
| Question removed when the session ends (`/exit` or tab closed) | **Validated** |
| **Go to Session** in Terminal.app, including two sessions in the same folder and a closed session whose TTY was reused | **Validated** live |
| Hook transport with TokenBar closed: no errors, no noticeable delay in Claude Code | **Validated** |
| **Open <App>** for apps without an exact target (VS Code, iTerm2) | Implemented and unit tested; brings the app to the front only |
| Approvals (permission prompts) | **Not counted**: see below |
| iTerm2, VS Code terminal and extension, tmux panes, other terminals | Missing: app activation only, or nothing |
| Listener authentication (shared secret) | Missing: any local process can post a fake question |
| Installing hooks from TokenBar (Settings, consent, safe edit of `~/.claude/settings.json`) | Missing: hooks are configured by hand per folder |
| Codex | Missing: no verified signal for a question |

## What counts as waiting

Only **structured questions**, Claude Code's `AskUserQuestion` tool. One entry per session
(provider + session ID): repeated events never count twice, and a resolved question never comes
back unless a new one is asked.

| Hook event | Effect |
|---|---|
| `PreToolUse` with `tool_name: AskUserQuestion` | The session waits for an answer |
| `PostToolUse` / `PostToolUseFailure` with `tool_name: AskUserQuestion` | Answered: removed (about 35 ms after the answer) |
| `UserPromptSubmit`, `Stop`, `StopFailure` | The session moved on: removed |
| `SessionEnd` | The session is gone: removed |
| **Dismiss** in the popover | Removed by hand |

**Esc on a question.** Claude Code sends no event when a question is cancelled with Esc. The
entry stays until you send the next prompt in that session (`UserPromptSubmit`), the session
ends, or you click **Dismiss**. A dismissed question does not come back; a new question from the
same session shows up again.

**Approvals are left out.** Captured with real sessions: `PermissionRequest` arrives before the
dialog, but approving sends nothing until the command **finishes** (20 s for `sleep 20`), and
denying or pressing Esc sends nothing at all until the next prompt. TokenBar cannot tell when you
have decided, so it would keep showing an approval that is no longer waiting.

## Transport

Claude Code `command` hooks pipe each payload to TokenBar with `/usr/bin/curl` over the loopback
interface and always exit 0:

```text
/usr/bin/curl -s -o /dev/null --connect-timeout 0.3 --max-time 1 -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:47811/hooks/claude; exit 0
```

- `type: "http"` hooks were tried first and rejected: while TokenBar is closed, Claude Code prints
  `hook error … ECONNREFUSED` on every prompt and tool call. The `curl` hook shows nothing.
- Cost: about 20–50 ms per event, the same with TokenBar open or closed. `--max-time 1` caps a
  listener that accepts a connection but never answers.
- `PreToolUse` and `PostToolUse` hooks use `matcher: "AskUserQuestion"`, so other tool calls run
  no hook at all.
- Events sent while TokenBar is closed are lost: a question asked before TokenBar starts does not
  appear.

The listener (`LocalHookServer`) binds to 127.0.0.1 only, accepts one small `POST` (256 KB at
most), and always answers `200` with an empty body, so a hook never makes a decision for Claude
Code. It reads `session_id`, `hook_event_name`, `tool_name`, the last component of `cwd`, and the
origin headers below. Nothing is stored or logged.

## Going back to the session

The session ID names the conversation. Where it is open (`AgentOrigin`) is separate and depends
on the environment. The hook that reports a question adds it as headers:

```text
-H "X-Origin-App: $__CFBundleIdentifier" -H "X-Origin-PID: $PPID" -H "X-Origin-TTY: $(/bin/ps -o tty= -p $PPID)"
```

`$PPID` is the Claude Code process. When the question arrives, TokenBar asks the kernel for that
process's terminal and start time and trusts the tab only if the kernel reports the same TTY.
Values that do not look exactly like a bundle ID, a process ID, or a TTY name are dropped (the TTY
ends up in an AppleScript).

| What is known | Button | Click |
|---|---|---|
| A Terminal.app tab whose Claude Code process is still running (same PID, start time, and TTY) | **Go to Session** | Selects that tab and brings its window to the front |
| Only the app (VS Code, iTerm2, or a session that ended) | **Open <App>** | Brings the app to the front |
| Nothing | — | Only **Dismiss** |

- The target is checked again on click. A closed tab's TTY is reused by the next tab within
  seconds (seen while testing), so a closed session shows "This session is no longer open." and
  never brings another tab to the front.
- A process that runs without its own tab (inside tmux) opens the app instead.
- Selecting a tab sends one Apple Event to Terminal. macOS asks once to allow TokenBar to control
  Terminal (System Settings › Privacy & Security › Automation). Debug builds carry the
  `com.apple.security.automation.apple-events` entitlement for this; Release builds do not.
- TokenBar never reopens the conversation (`claude --resume`) and never types into the session.
- `$__CFBundleIdentifier` comes from the environment and can be inherited: a tmux server started
  in one app and attached from another reports the first app.

Adding an environment (iTerm2 via `ITERM_SESSION_ID`, VS Code, tmux) means a new
`AgentOrigin.Target` case and its support in `MacAgentNavigationEnvironment`. The popover and the
decision logic (`AgentSessionNavigator`) stay the same.

## Code

| Piece | Where |
|---|---|
| Sessions, events, store, origin, navigation decisions | `TokenBarCore/Agents` |
| Hook payload and origin parsing, loopback listener | `TokenBarProviders/Claude/Hooks` |
| Process lookup (`sysctl`), Terminal tab selection, app activation | `TokenBarProviders/Navigation` |
| Menu bar indicator, Agents page | `TokenBarUI/MenuBarLabel.swift`, `TokenBarUI/Popover/AgentsSection.swift` |
| Debug-only wiring (`TOKENBAR_AGENT_HOOKS`, `TOKENBAR_AGENT_HOOKS_PORT`) | `TokenBar/ProviderRegistry.swift`, `TokenBar/AppDelegate.swift` |

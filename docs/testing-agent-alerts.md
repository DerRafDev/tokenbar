# Testing agent alerts (Debug)

How to try the experimental Claude Code alerts on your own Mac: a question from Claude Code shows
`● Claude · 1` in the menu bar, the popover opens on **Agents**, **Go to Session** brings the
Terminal tab with the question to the front, and answering returns the menu bar to usage.
Background and limits: [agents.md](agents.md).

Nothing here touches your global Claude Code settings. The hooks live in one test folder.

## Requirements

- macOS 14+, Xcode 26+, this repository.
- Claude Code signed in (`claude --version`). Tested with 2.1.116 and 2.1.319.
- Terminal.app for **Go to Session**. Other terminals and VS Code get **Open <App>** only.

## 1. Turn the prototype on in Xcode

1. Open `apps/macos/TokenBar.xcodeproj`.
2. **Product › Scheme › Edit Scheme… › Run › Arguments › Environment Variables**.
3. Check **`TOKENBAR_AGENT_HOOKS`** (value `1`). Optionally also check `TOKENBAR_DEMO` to see
   demo usage numbers instead of enabling real providers.
4. Run with **⌘R** (Debug). TokenBar now listens on `127.0.0.1:47811`.

Both flags are listed in the shared scheme, unchecked. Uncheck them again before committing:
`scripts/test.sh` fails while `TOKENBAR_AGENT_HOOKS` is checked in the shared scheme.

To confirm the listener runs:

```sh
lsof -nP -iTCP:47811 -sTCP:LISTEN     # shows TokenBar
```

## 2. Create a test folder with the hooks

The hooks go in `.claude/settings.local.json` of a test folder, so only Claude Code sessions
started there report to TokenBar. Paste this in a terminal:

```sh
TEST_DIR="$HOME/tokenbar-agent-test"
mkdir -p "$TEST_DIR/.claude"
cat > "$TEST_DIR/.claude/settings.local.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "/usr/bin/curl -s -o /dev/null --connect-timeout 0.3 --max-time 1 -H 'Content-Type: application/json' -H \"X-Origin-App: $__CFBundleIdentifier\" -H \"X-Origin-PID: $PPID\" -H \"X-Origin-TTY: $(/bin/ps -o tty= -p $PPID)\" --data-binary @- http://127.0.0.1:47811/hooks/claude; exit 0",
            "timeout": 3
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [{ "type": "command", "command": "/usr/bin/curl -s -o /dev/null --connect-timeout 0.3 --max-time 1 -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:47811/hooks/claude; exit 0", "timeout": 3 }]
      }
    ],
    "PostToolUseFailure": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [{ "type": "command", "command": "/usr/bin/curl -s -o /dev/null --connect-timeout 0.3 --max-time 1 -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:47811/hooks/claude; exit 0", "timeout": 3 }]
      }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "/usr/bin/curl -s -o /dev/null --connect-timeout 0.3 --max-time 1 -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:47811/hooks/claude; exit 0", "timeout": 3 }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "/usr/bin/curl -s -o /dev/null --connect-timeout 0.3 --max-time 1 -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:47811/hooks/claude; exit 0", "timeout": 3 }] }
    ],
    "StopFailure": [
      { "hooks": [{ "type": "command", "command": "/usr/bin/curl -s -o /dev/null --connect-timeout 0.3 --max-time 1 -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:47811/hooks/claude; exit 0", "timeout": 3 }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "/usr/bin/curl -s -o /dev/null --connect-timeout 0.3 --max-time 1 -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:47811/hooks/claude; exit 0", "timeout": 3 }] }
    ]
  }
}
EOF
```

What the hooks do:

- Each one posts the hook's JSON to TokenBar with `/usr/bin/curl` and always exits 0. With
  TokenBar closed, Claude Code shows no error and no noticeable delay.
- `PreToolUse` and `PostToolUse` only run for `AskUserQuestion`; other tool calls run no hook.
- The question hook also sends where the session runs: the app (`$__CFBundleIdentifier`), the
  Claude Code process (`$PPID`), and its terminal (`ps -o tty=`). TokenBar uses them for
  **Go to Session**.

## 3. Start Claude Code in Terminal.app

In **Terminal.app**:

```sh
cd "$HOME/tokenbar-agent-test"
claude
```

The first time, Claude Code asks whether you trust the folder. With command hooks present,
**"No, exit" is preselected**: choose **Yes, I trust this folder**. Hooks load when a session
starts, so restart any session opened before you created the file.

## 4. Test the flow

Ask for a structured question:

```text
Use the AskUserQuestion tool to ask me which color I prefer, Red or Blue.
```

| Step | Expected |
|---|---|
| The question appears in Terminal | The menu bar shows an amber dot and **Claude · 1** |
| Click the menu bar | The popover opens on **Agents (1)** › **Waiting for you**: "Claude Code · tokenbar-agent-test", "Terminal · Waiting for an answer · now", **Go to Session** and **Dismiss** |
| Switch to another app, open the popover, click **Go to Session** | The first time, macOS asks: *"TokenBar" wants access to control "Terminal"*. Click **Allow**. Terminal comes to the front with the tab that holds the question |
| Answer the question in Terminal | The entry disappears and the menu bar returns to your usage display |

### Two sessions

1. In Terminal, open a second window (**⌘N**), `cd "$HOME/tokenbar-agent-test"`, run `claude`,
   and ask the same question. Keep the first question open too.
2. The menu bar shows **Claude · 2**; the popover lists both sessions, longest-waiting first.
3. Click **Go to Session** on each row, switching to another app in between. Each click brings
   its own window and tab to the front, even though both sessions are in the same folder.
4. Answer one question: **Claude · 1**. Answer the other: the menu bar returns to usage.

### Cancel with Esc

Press **Esc** on a question instead of answering. Claude Code sends no event for this, so the
entry **stays**. It goes away when you send the next prompt in that session, when the session
ends, or when you click **Dismiss**.

### Closed session

Ask a question, then close that Terminal window (confirm **Terminate**). Claude Code reports the
end of the session and the entry disappears. A target that went stale while still listed shows
"This session is no longer open." and brings no other tab to the front; this case is covered by
`AgentSessionNavigatorTests`.

### Other checks

- **Minimal display** (Settings › General › Display): the menu bar shows only the count, `● 2`.
- **Other apps:** a question asked from VS Code's terminal shows **Open Visual Studio Code**,
  which brings the app to the front (not the exact terminal).
- **TokenBar closed:** quit TokenBar and keep using Claude Code in the test folder. No hook
  errors appear.

## Troubleshooting

- **Nothing appears.** Check that `TOKENBAR_AGENT_HOOKS` is checked and the listener runs
  (`lsof` above), that the session started in the test folder after you created the hooks, and
  that the folder is trusted. Watch TokenBar's log:

  ```sh
  log stream --predicate 'subsystem == "io.github.derrafdev.TokenBar" AND category == "agents"'
  ```

- **Port 47811 is taken** (another TokenBar build is running). Add `TOKENBAR_AGENT_HOOKS_PORT`
  with another port, such as `47813`, to the scheme's environment variables and point the hooks
  at it:

  ```sh
  sed -i '' 's/127.0.0.1:47811/127.0.0.1:47813/g' "$HOME/tokenbar-agent-test/.claude/settings.local.json"
  ```

- **Go to Session does nothing.** You may have denied the Automation prompt. Turn **Terminal**
  on for TokenBar in **System Settings › Privacy & Security › Automation**, or reset the answer
  and click again:

  ```sh
  tccutil reset AppleEvents io.github.derrafdev.TokenBar
  ```

  Debug builds are signed ad hoc, so macOS may ask again after a rebuild.

## Clean up

```sh
rm -r "$HOME/tokenbar-agent-test"
tccutil reset AppleEvents io.github.derrafdev.TokenBar
```

Uncheck `TOKENBAR_AGENT_HOOKS` in the scheme.

import Foundation
import Testing
import TokenBarCore

@testable import TokenBarProviders

struct ClaudeHookMapperTests {
    let date = Date(timeIntervalSince1970: 1_000_000)

    /// A sanitized payload with the fields Claude Code sends; only some are read.
    private func payload(_ event: String, tool: String? = nil, session: String = "session-1") -> Data {
        var json: [String: Any] = [
            "session_id": session,
            "hook_event_name": event,
            "cwd": "/Users/someone/projects/tokenbar",
            "transcript_path": "/Users/someone/.claude/projects/x/session-1.jsonl",
            "permission_mode": "default",
        ]
        if let tool {
            json["tool_name"] = tool
            json["tool_input"] = ["questions": [["question": "Which color?", "options": [["label": "Red"]]]]]
            json["tool_use_id"] = "call-1"
        }
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func kind(_ event: String, tool: String? = nil) -> AgentEvent.Kind? {
        ClaudeHookMapper.event(from: payload(event, tool: tool), date: date)?.kind
    }

    @Test func questionWaitsForAnAnswer() throws {
        let event = try #require(
            ClaudeHookMapper.event(from: payload("PreToolUse", tool: "AskUserQuestion"), date: date))
        #expect(event.kind == .waiting(.answer))
        #expect(event.key == AgentSessionKey(provider: "claude", sessionID: "session-1"))
        #expect(event.project == "tokenbar")
        #expect(event.agentName == "Claude Code")
        #expect(event.date == date)
    }

    private let started = Date(timeIntervalSince1970: 5_000)
    private let originHeaders = [
        "x-origin-app": "com.apple.Terminal", "x-origin-pid": "4242", "x-origin-tty": "ttys005",
    ]

    @Test func questionKeepsTerminalTabWhenTheProcessOwnsIt() throws {
        let event = try #require(
            ClaudeHookMapper.event(
                from: payload("PreToolUse", tool: "AskUserQuestion"), headers: originHeaders, date: date,
                process: { $0 == 4242 ? ProcessSnapshot(startedAt: started, tty: "ttys005") : nil }))
        #expect(
            event.origin
                == AgentOrigin(
                    appBundleID: "com.apple.Terminal",
                    target: .terminalTab(tty: "ttys005", process: AgentProcess(id: 4242, startedAt: started))))
    }

    @Test func terminalClaimNotConfirmedByTheKernelKeepsOnlyTheApp() {
        let otherTTY: (Int32) -> ProcessSnapshot? = { _ in ProcessSnapshot(startedAt: started, tty: "ttys009") }
        let gone: (Int32) -> ProcessSnapshot? = { _ in nil }
        for process in [otherTTY, gone] {
            let event = ClaudeHookMapper.event(
                from: payload("PreToolUse", tool: "AskUserQuestion"), headers: originHeaders, date: date,
                process: process)
            #expect(event?.origin == AgentOrigin(appBundleID: "com.apple.Terminal"))
        }
    }

    /// Header values end up in an AppleScript and a process lookup, so anything unexpected is dropped.
    @Test func malformedOriginHeadersAreDropped() {
        let process: (Int32) -> ProcessSnapshot? = { _ in ProcessSnapshot(startedAt: started, tty: "ttys005") }
        let bad: [[String: String]] = [
            ["x-origin-app": "com.apple.Terminal\" end tell", "x-origin-pid": "4242", "x-origin-tty": "ttys005"],
            ["x-origin-app": ""],
            [:],
        ]
        for headers in bad {
            let event = ClaudeHookMapper.event(
                from: payload("PreToolUse", tool: "AskUserQuestion"), headers: headers, date: date, process: process)
            #expect(event?.origin == nil)
        }
        let badTTY = ClaudeHookMapper.event(
            from: payload("PreToolUse", tool: "AskUserQuestion"),
            headers: ["x-origin-app": "com.apple.Terminal", "x-origin-pid": "4242", "x-origin-tty": "ttys005\" & x"],
            date: date, process: process)
        #expect(badTTY?.origin == AgentOrigin(appBundleID: "com.apple.Terminal"))
    }

    @Test func onlyWaitingEventsCarryAnOrigin() {
        let event = ClaudeHookMapper.event(
            from: payload("PostToolUse", tool: "AskUserQuestion"), headers: originHeaders, date: date)
        #expect(event?.origin == nil)
    }

    @Test func answerResolvesTheQuestion() {
        #expect(kind("PostToolUse", tool: "AskUserQuestion") == .resolved)
        #expect(kind("PostToolUseFailure", tool: "AskUserQuestion") == .resolved)
    }

    /// Approvals are left out: Claude Code reports no event when the user approves or denies.
    @Test func otherToolsAndApprovalsAreIgnored() {
        #expect(kind("PreToolUse", tool: "Bash") == nil)
        #expect(kind("PostToolUse", tool: "Bash") == nil)
        #expect(kind("PermissionRequest", tool: "Bash") == nil)
        #expect(kind("PermissionRequest", tool: "AskUserQuestion") == nil)
        #expect(kind("Notification") == nil)
        #expect(kind("SubagentStop") == nil)
        #expect(kind("SessionStart") == nil)
    }

    @Test func newPromptOrEndOfTurnResolves() {
        #expect(kind("UserPromptSubmit") == .resolved)
        #expect(kind("Stop") == .resolved)
        #expect(kind("StopFailure") == .resolved)
    }

    @Test func sessionEndEnds() {
        #expect(kind("SessionEnd") == .ended)
    }

    @Test func invalidPayloadsAreIgnored() {
        #expect(ClaudeHookMapper.event(from: Data("not json".utf8), date: date) == nil)
        #expect(ClaudeHookMapper.event(from: Data(#"{"hook_event_name":"Stop"}"#.utf8), date: date) == nil)
        #expect(
            ClaudeHookMapper.event(from: Data(#"{"hook_event_name":"Stop","session_id":""}"#.utf8), date: date) == nil)
    }

    /// Sequences captured from Claude Code 2.1.319 (docs/agents.md), replayed through the store.
    @MainActor
    @Test(arguments: [
        // Question answered.
        (["UserPromptSubmit", "PreToolUse:AskUserQuestion", "PermissionRequest:AskUserQuestion"], 1),
        (
            [
                "UserPromptSubmit", "PreToolUse:AskUserQuestion", "PermissionRequest:AskUserQuestion",
                "Notification", "PostToolUse:AskUserQuestion", "Stop",
            ], 0
        ),
        // Question dismissed with Esc: nothing is sent until the next prompt.
        (
            [
                "UserPromptSubmit", "PreToolUse:AskUserQuestion", "PermissionRequest:AskUserQuestion",
                "Notification",
            ], 1
        ),
        (
            [
                "UserPromptSubmit", "PreToolUse:AskUserQuestion", "PermissionRequest:AskUserQuestion",
                "Notification", "UserPromptSubmit",
            ], 0
        ),
        // A Bash approval never counts.
        (["UserPromptSubmit", "PreToolUse:Bash", "PermissionRequest:Bash", "Notification"], 0),
        // Session closed while asking.
        (["PreToolUse:AskUserQuestion", "SessionEnd"], 0),
    ])
    func capturedSequences(steps: [String], expected: Int) {
        let store = AgentActivityStore()
        for step in steps {
            let parts = step.split(separator: ":").map(String.init)
            if let event = ClaudeHookMapper.event(
                from: payload(parts[0], tool: parts.count > 1 ? parts[1] : nil), date: date)
            {
                store.apply(event)
            }
        }
        #expect(store.pendingCount == expected)
    }
}

struct HookHTTPRequestTests {
    private func request(_ head: String, body: String = "") -> Data {
        Data((head + "\r\n\r\n" + body).utf8)
    }

    @Test func parsesPostWithBody() {
        let data = request("POST /hooks/claude HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 2", body: "{}")
        #expect(
            HookHTTPRequest.parse(data)
                == .post(
                    path: "/hooks/claude", headers: ["host": "127.0.0.1", "content-length": "2"], body: Data("{}".utf8))
        )
    }

    @Test func headerNamesAreCaseInsensitive() {
        let data = request("POST /x HTTP/1.1\r\ncontent-length: 1", body: "a")
        #expect(
            HookHTTPRequest.parse(data) == .post(path: "/x", headers: ["content-length": "1"], body: Data("a".utf8)))
    }

    @Test func waitsForTheWholeRequest() {
        #expect(HookHTTPRequest.parse(Data("POST /x HTTP/1.1\r\nContent-Le".utf8)) == .incomplete)
        #expect(HookHTTPRequest.parse(request("POST /x HTTP/1.1\r\nContent-Length: 10", body: "{}")) == .incomplete)
    }

    @Test func rejectsOtherMethodsAndMissingLength() {
        #expect(HookHTTPRequest.parse(request("GET /x HTTP/1.1")) == .rejected)
        #expect(HookHTTPRequest.parse(request("POST /x HTTP/1.1")) == .rejected)
        #expect(HookHTTPRequest.parse(request("garbage")) == .rejected)
    }

    @Test func rejectsOversizedRequests() {
        let body = String(repeating: "a", count: HookHTTPRequest.maxSize)
        #expect(
            HookHTTPRequest.parse(request("POST /x HTTP/1.1\r\nContent-Length: \(body.count)", body: body)) == .rejected
        )
    }
}

/// End to end over the loopback interface, as Claude Code's `curl` hook sends it.
struct ClaudeHookSourceTests {
    @Test func deliversQuestionPostedOverHTTP() async throws {
        let port = UInt16.random(in: 49_152...60_000)
        let source = ClaudeHookSource(port: port)
        let events = try source.start()
        defer { source.stop() }

        let body = Data(
            #"{"session_id":"session-1","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","cwd":"/tmp/demo"}"#
                .utf8)
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(ClaudeHookSource.path)")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // The listener may need a moment to become ready.
        var response: URLResponse?
        for _ in 0..<20 {
            if let (_, sent) = try? await URLSession.shared.data(for: request) {
                response = sent
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)

        var iterator = events.makeAsyncIterator()
        let event = await iterator.next()
        #expect(event?.kind == .waiting(.answer))
        #expect(event?.project == "demo")
    }
}

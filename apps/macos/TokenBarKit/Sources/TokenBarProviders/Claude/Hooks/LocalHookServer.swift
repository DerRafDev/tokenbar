import Foundation
import Network
import OSLog
import TokenBarCore

/// Receives hook payloads over HTTP on the loopback interface only.
///
/// Always answers `200` with an empty body, so a hook never makes a decision for Claude Code.
/// Requests are handed to `onRequest` and never stored or logged.
final class LocalHookServer: @unchecked Sendable {
    let port: UInt16
    let path: String
    private let queue = DispatchQueue(label: "io.github.derrafdev.TokenBar.hooks")
    private let logger = Logger(subsystem: Log.subsystem, category: "agents")
    // Accessed on `queue` only.
    private var listener: NWListener?

    init(port: UInt16, path: String) {
        self.port = port
        self.path = path
    }

    func start(onRequest: @escaping @Sendable ([String: String], Data) -> Void) throws {
        guard port != 0, let endpointPort = NWEndpoint.Port(rawValue: port) else { throw NWError.posix(.EINVAL) }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: endpointPort)
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection, onRequest: onRequest)
        }
        listener.stateUpdateHandler = { [logger, port] state in
            switch state {
            case .ready: logger.notice("Listening for agent hooks on 127.0.0.1:\(port, privacy: .public)")
            case .failed(let error):
                logger.error("Hook listener failed: \(String(describing: error), privacy: .public)")
            default: break
            }
        }
        queue.sync { self.listener = listener }
        listener.start(queue: queue)
    }

    func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
        }
    }

    private func handle(_ connection: NWConnection, onRequest: @escaping @Sendable ([String: String], Data) -> Void) {
        connection.start(queue: queue)
        receive(connection, buffer: Data(), onRequest: onRequest)
        // A client that never finishes its request is dropped.
        queue.asyncAfter(deadline: .now() + 5) { connection.cancel() }
    }

    private func receive(
        _ connection: NWConnection, buffer: Data, onRequest: @escaping @Sendable ([String: String], Data) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return connection.cancel() }
            var buffer = buffer
            if let data { buffer.append(data) }
            switch HookHTTPRequest.parse(buffer) {
            case .incomplete where !isComplete && error == nil:
                self.receive(connection, buffer: buffer, onRequest: onRequest)
            case .post(let path, let headers, let body) where path == self.path:
                onRequest(headers, body)
                self.respond(connection, status: "200 OK")
            case .post:
                self.respond(connection, status: "404 Not Found")
            default:
                self.respond(connection, status: "400 Bad Request")
            }
        }
    }

    private func respond(_ connection: NWConnection, status: String) {
        let response = Data("HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}

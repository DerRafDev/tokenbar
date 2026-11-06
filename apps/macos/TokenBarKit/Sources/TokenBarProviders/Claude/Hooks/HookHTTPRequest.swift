import Foundation

/// The small part of HTTP/1.1 the hook listener needs: one `POST` with a `Content-Length` body.
enum HookHTTPRequest: Equatable {
    /// More bytes are needed.
    case incomplete
    /// Not a request the listener accepts. The connection is closed.
    case rejected
    /// Header names are lowercased.
    case post(path: String, headers: [String: String], body: Data)

    /// Largest accepted request, headers included. Hook payloads are a few kilobytes.
    static let maxSize = 256 * 1024

    static func parse(_ data: Data) -> HookHTTPRequest {
        guard data.count <= maxSize else { return .rejected }
        guard let headerEnd = data.firstRange(of: Data("\r\n\r\n".utf8)) else {
            return .incomplete
        }
        guard let head = String(data: data[data.startIndex..<headerEnd.lowerBound], encoding: .utf8) else {
            return .rejected
        }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count == 3, requestLine[0] == "POST" else { return .rejected }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard let length = headers["content-length"].flatMap(Int.init), length >= 0 else { return .rejected }

        let bodyStart = headerEnd.upperBound
        let available = data.endIndex - bodyStart
        if available < length { return .incomplete }
        return .post(
            path: String(requestLine[1]), headers: headers, body: Data(data[bodyStart..<(bodyStart + length)]))
    }
}

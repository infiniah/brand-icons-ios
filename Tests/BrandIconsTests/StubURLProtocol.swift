import Foundation

/// Answers requests from a routing table instead of the network.
///
/// Routes are keyed by a token each ``StubbedNetwork`` puts on its own requests, because
/// Swift Testing runs suites in parallel and a single shared table lets one suite's `reset`
/// erase another suite's routes mid-flight.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        var statusCode = 200
        var headers: [String: String] = [:]
        var body = Data()

        static func image(_ bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47]) -> Response {
            Response(headers: ["Content-Type": "image/png"], body: Data(bytes))
        }

        static func json(_ raw: String) -> Response {
            Response(headers: ["Content-Type": "application/json"], body: Data(raw.utf8))
        }

        static func png(_ data: Data) -> Response {
            Response(headers: ["Content-Type": "image/png"], body: data)
        }

        static func html(_ markup: String) -> Response {
            Response(headers: ["Content-Type": "text/html; charset=utf-8"], body: Data(markup.utf8))
        }

        static func html() -> Response {
            Response(
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: Data("<html>not an icon</html>".utf8)
            )
        }

        static let notFound = Response(statusCode: 404)
    }

    enum Match: Sendable {
        case substring(String)
        case exact(String)

        func matches(_ absolute: String) -> Bool {
            switch self {
            case let .substring(value): return absolute.contains(value)
            case let .exact(value): return absolute == value
            }
        }
    }

    static let tokenHeader = "X-Stub-Token"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var routes: [String: [(match: Match, response: Response)]] = [:]
    nonisolated(unsafe) private static var seen: [String: [String]] = [:]

    static func stub(_ match: Match, with response: Response, token: String) {
        lock.withLock { routes[token, default: []].append((match, response)) }
    }

    static func requestedURLs(token: String) -> [String] {
        lock.withLock { seen[token] ?? [] }
    }

    static func forget(token: String) {
        lock.withLock {
            routes[token] = nil
            seen[token] = nil
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let token = request.value(forHTTPHeaderField: Self.tokenHeader) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let absolute = url.absoluteString
        let stub = Self.lock.withLock { () -> Response in
            Self.seen[token, default: []].append(absolute)
            return Self.routes[token]?.first { $0.match.matches(absolute) }?.response ?? .notFound
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !stub.body.isEmpty {
            client?.urlProtocol(self, didLoad: stub.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

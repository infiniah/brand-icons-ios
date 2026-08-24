import Foundation

/// A `URLSession` that answers only what this instance was told to answer.
///
/// Anything unstubbed comes back 404, which is the case most of the provider tests are about.
struct StubbedNetwork {
    let session: URLSession
    private let token: String

    init() {
        let token = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [StubURLProtocol.tokenHeader: token]
        self.token = token
        self.session = URLSession(configuration: configuration)
    }

    func stub(containing match: String, with response: StubURLProtocol.Response) {
        StubURLProtocol.stub(.substring(match), with: response, token: token)
    }

    /// For a route whose URL is a prefix of every other route on the same host, such as the
    /// document root against which relative icon paths resolve.
    func stub(url: String, with response: StubURLProtocol.Response) {
        StubURLProtocol.stub(.exact(url), with: response, token: token)
    }

    var requestedURLs: [String] {
        StubURLProtocol.requestedURLs(token: token)
    }
}

import Foundation

/// Fetches image bytes and refuses anything that is not an image.
///
/// Every network provider needs the same guard. A host that has no icon at the path we asked
/// for very often answers `200` with an HTML error page, and a CDN that wants a credential
/// answers `302` to its own documentation. Both look like success to `URLSession`, so the
/// status code alone is not enough: the content type has to say `image`.
struct IconDownloader: Sendable {
    let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    /// Image bytes, or `nil` when the resource is absent or is not an image.
    ///
    /// Throws only for conditions the caller can act on, such as being rate limited.
    func imageData(from url: URL, referer: String? = nil) async throws -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw BrandIconError.transport(error.localizedDescription)
        } catch {
            return nil
        }

        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 429 {
            throw BrandIconError.rateLimited(retryAfter: Self.retryAfter(from: http))
        }
        guard (200..<300).contains(http.statusCode), !data.isEmpty else { return nil }

        let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard contentType.hasPrefix("image/") else { return nil }
        return data
    }

    /// Decoded JSON, or `nil` when the response is absent or unreadable.
    func json(from url: URL) async throws -> [String: Any]? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw BrandIconError.transport(error.localizedDescription)
        } catch {
            return nil
        }

        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 429 {
            throw BrandIconError.rateLimited(retryAfter: Self.retryAfter(from: http))
        }
        guard (200..<300).contains(http.statusCode) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Raw bytes for a non-image resource such as a manifest, or `nil` when it is absent.
    func data(from url: URL) async throws -> Data? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/manifest+json,application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw BrandIconError.transport(error.localizedDescription)
        } catch {
            return nil
        }

        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 429 {
            throw BrandIconError.rateLimited(retryAfter: Self.retryAfter(from: http))
        }
        guard (200..<300).contains(http.statusCode), !data.isEmpty else { return nil }
        return data
    }

    /// Markup up to and including `</head>`, or `nil` when the page is absent or unreadable.
    ///
    /// Streams rather than downloads: a `<link>` tag sits in the first few kilobytes and a home
    /// page is routinely a megabyte, so iteration stops at the closing head tag and a byte cap
    /// covers pages that never emit one.
    func headMarkup(from url: URL, maxBytes: Int = 262_144) async throws -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let stream: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (stream, response) = try await session.bytes(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw BrandIconError.transport(error.localizedDescription)
        } catch {
            return nil
        }

        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 429 {
            throw BrandIconError.rateLimited(retryAfter: Self.retryAfter(from: http))
        }
        guard (200..<300).contains(http.statusCode) else { return nil }

        let terminator = Array("</head>".utf8)
        var buffer: [UInt8] = []
        buffer.reserveCapacity(min(maxBytes, 16_384))

        do {
            for try await byte in stream {
                buffer.append(byte)
                if buffer.count >= terminator.count,
                   buffer.suffix(terminator.count).map({ $0 | 0x20 }).elementsEqual(terminator) {
                    break
                }
                if buffer.count >= maxBytes { break }
            }
        } catch {
            guard !buffer.isEmpty else { return nil }
        }

        return buffer.isEmpty ? nil : String(decoding: buffer, as: UTF8.self)
    }

    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(raw)
    }
}

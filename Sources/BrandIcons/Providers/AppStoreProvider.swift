import Foundation

/// App Store artwork, via the iTunes Search API.
///
/// Off unless you turn it on, and inert if constructed without ``isEnabled``, because two
/// facts about this source belong to the adopter rather than to this package.
///
/// Apple limits the Search API to roughly twenty requests per minute per client and answers
/// `429` beyond that. Apple's terms describe App Store artwork as promotional material for
/// store content, to be displayed near a store badge that links to the store. Labelling a row
/// of your own interface with an app icon is a different use from the one described there.
///
/// Both statements are here so the decision is made knowingly. This package does not make it
/// for you and does not recommend either way.
public struct AppStoreProvider: BrandIconProvider {
    public let source: BrandIconSource = .appStore

    /// Whether the provider may make requests at all. When false it returns no candidates and
    /// throws ``BrandIconError/providerDisabled(_:)`` rather than fetching anything.
    public let isEnabled: Bool

    private let country: String
    private let limit: Int
    private let downloader: IconDownloader
    private let memo: ArtworkMemo

    /// - Parameters:
    ///   - isEnabled: Must be set explicitly. The default leaves the provider inert.
    ///   - country: App Store storefront to search.
    ///   - limit: Most results to consider.
    ///   - session: Injected so the provider can be exercised without the network.
    public init(
        isEnabled: Bool = false,
        country: String = "US",
        limit: Int = 3,
        session: URLSession = .shared
    ) {
        self.isEnabled = isEnabled
        self.country = country
        self.limit = max(1, limit)
        self.downloader = IconDownloader(session: session)
        self.memo = ArtworkMemo()
    }

    public func candidates(for query: BrandQuery) async throws -> [BrandIconCandidate] {
        guard isEnabled else { return [] }
        guard let url = searchURL(for: query.name) else { return [] }
        guard let payload = try await downloader.json(from: url) else { return [] }
        guard let results = payload["results"] as? [[String: Any]] else {
            throw BrandIconError.unreadableResponse
        }

        var candidates: [BrandIconCandidate] = []
        for result in results {
            guard let bundleID = result["bundleId"] as? String,
                  let trackName = result["trackName"] as? String,
                  let artwork = result["artworkUrl512"] as? String,
                  let artworkURL = URL(string: artwork) else { continue }

            await memo.store(artworkURL, for: bundleID)
            candidates.append(
                BrandIconCandidate(
                    slug: bundleID,
                    title: trackName,
                    confidence: MatchScorer.score(query: query.name, name: trackName),
                    source: source
                )
            )
        }
        return candidates.sorted { $0.confidence > $1.confidence }
    }

    public func shape(for candidate: BrandIconCandidate) async throws -> BrandIconShape {
        guard isEnabled else { throw BrandIconError.providerDisabled(source) }
        if let shape = candidate.shape { return shape }

        guard let artworkURL = try await artworkURL(forBundleID: candidate.slug) else {
            throw BrandIconError.notFound
        }
        guard let data = try await downloader.imageData(from: artworkURL) else {
            throw BrandIconError.notFound
        }
        return .raster(data: data)
    }

    /// The artwork URL remembered from the search, or a fresh lookup by bundle id.
    ///
    /// The lookup costs a request against the same twenty a minute the search does, so the
    /// memo is what keeps the common path to one request rather than two.
    private func artworkURL(forBundleID bundleID: String) async throws -> URL? {
        if let remembered = await memo.url(for: bundleID) { return remembered }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: country)
        ]
        guard let url = components.url,
              let payload = try await downloader.json(from: url),
              let results = payload["results"] as? [[String: Any]],
              let artwork = results.first?["artworkUrl512"] as? String else { return nil }

        let artworkURL = URL(string: artwork)
        if let artworkURL { await memo.store(artworkURL, for: bundleID) }
        return artworkURL
    }

    func searchURL(for term: String) -> URL? {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "country", value: country)
        ]
        return components.url
    }
}

private actor ArtworkMemo {
    private var urls: [String: URL] = [:]

    func store(_ url: URL, for bundleID: String) {
        urls[bundleID] = url
    }

    func url(for bundleID: String) -> URL? {
        urls[bundleID]
    }
}

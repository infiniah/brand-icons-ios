import Foundation

/// The service's own site, via the icons it declares.
///
/// No third party sits between the user and the brand, which is the point: an icon service
/// would work just as well and would also learn every domain your users look up. That is the
/// reason this tier reads the site directly rather than proxying through anyone.
///
/// It looks in the order a site is most likely to be truthful, largest usable icon first:
///
/// 1. the Web App Manifest at `/site.webmanifest` or `/manifest.json`, whose `icons` array is
///    where a modern site puts its 192 and 512 pixel marks
/// 2. the document head, whose `<link rel="apple-touch-icon">` and `rel="icon"` tags are the
///    only place a hashed or CDN icon path exists, and whose `rel="manifest"` points at a
///    manifest that is not on a well known path
/// 3. `/apple-touch-icon.png` and `/favicon.ico`, guessed, and last because they usually are
///    not there and `favicon.ico` is usually 16 or 32 pixels
///
/// ## Why the confidence looks the way it does
///
/// Two separate things are uncertain here and both belong in the number.
///
/// The first is whether this is the right brand at all. A site answering on a host proves the
/// host exists, not that it belongs to the company the user meant, and when the domain was
/// guessed from a statement descriptor rather than supplied it is often not. That caps the
/// whole tier at ``ceiling``, well under a real vector mark.
///
/// The second is whether the icon is usable. A 16 pixel `.ico` drawn at 44 points is four
/// pixels per point of blur on a 3x screen, and reporting it as confidently as a 512 pixel
/// manifest icon told the caller nothing. So the match score sets the range and the measured
/// resolution scales within it, on a log curve because the useful spread is 128 to 512 rather
/// than 16 to 512. The size is measured from the bytes that arrived, not from what the site
/// claimed, so a site that declares `512x512` and serves a 32 pixel file scores as 32.
public struct FaviconProvider: BrandIconProvider {
    public let source: BrandIconSource = .favicon

    /// Guessed last, and only when the site declared nothing.
    static let fallbackPaths = ["/apple-touch-icon.png", "/apple-touch-icon-precomposed.png", "/favicon.ico"]

    static let manifestPaths = ["/site.webmanifest", "/manifest.json"]

    static let floor = 0.35
    static let ceiling = 0.65

    /// Below this an icon is too small to draw at 44 points on a 3x screen without blurring.
    static let usableSize = 128

    private let downloader: IconDownloader

    public init(session: URLSession = .shared) {
        self.downloader = IconDownloader(session: session)
    }

    public func candidates(for query: BrandQuery) async throws -> [BrandIconCandidate] {
        let domain = query.domain ?? query.inferredDomain
        guard let icon = try await bestIcon(on: domain) else { return [] }

        let label = DomainLabel.secondLevel(of: domain)
        return [
            BrandIconCandidate(
                slug: domain,
                title: label.capitalized,
                confidence: Self.confidence(
                    match: MatchScorer.score(query: query.name, name: label, slug: label),
                    pixelSize: icon.pixelSize
                ),
                source: source,
                shape: .raster(data: icon.data)
            )
        ]
    }

    public func shape(for candidate: BrandIconCandidate) async throws -> BrandIconShape {
        if let shape = candidate.shape { return shape }
        guard let icon = try await bestIcon(on: candidate.slug) else { throw BrandIconError.notFound }
        return .raster(data: icon.data)
    }

    private struct FetchedIcon {
        let data: Data
        let pixelSize: Int?
    }

    private func bestIcon(on domain: String) async throws -> FetchedIcon? {
        let normalized = BrandQuery.normalizeDomain(domain)
        guard !normalized.isEmpty, let root = Self.url(host: normalized, path: "/") else { return nil }

        for path in Self.manifestPaths {
            guard let manifestURL = Self.url(host: normalized, path: path) else { continue }
            guard let data = try await downloader.data(from: manifestURL) else { continue }
            if let icon = try await download(WebManifestParser.icons(in: data, manifestURL: manifestURL)) {
                return icon
            }
        }

        if let markup = try await downloader.headMarkup(from: root) {
            let declarations = IconLinkParser.declarations(in: markup, documentURL: root)

            if let manifestURL = declarations.manifestURL,
               !Self.manifestPaths.contains(manifestURL.path),
               let data = try await downloader.data(from: manifestURL),
               let icon = try await download(WebManifestParser.icons(in: data, manifestURL: manifestURL)) {
                return icon
            }

            if let icon = try await download(declarations.icons) {
                return icon
            }
        }

        return try await download(
            Self.fallbackPaths.compactMap { path in
                Self.url(host: normalized, path: path)
                    .map { DeclaredIcon(url: $0, declaredPixelSize: nil, assumedPixelSize: 0) }
            },
            ranked: false
        )
    }

    static func url(host: String, path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        return components.url
    }

    /// The first declaration that really answers with an image, best declared first.
    private func download(_ icons: [DeclaredIcon], ranked: Bool = true) async throws -> FetchedIcon? {
        let ordered = ranked ? icons.sorted(by: DeclaredIcon.betterFirst) : icons
        for icon in ordered {
            guard let data = try await downloader.imageData(from: icon.url) else { continue }
            return FetchedIcon(data: data, pixelSize: ImagePixelSize.shortestSide(of: data) ?? icon.declaredPixelSize)
        }
        return nil
    }

    /// Match strength sets the range, measured resolution scales within it.
    static func confidence(match: Double, pixelSize: Int?) -> Double {
        floor + (ceiling - floor) * match * (0.4 + 0.6 * resolutionScore(pixelSize))
    }

    /// 0 at 16 pixels, 1 at 512, log scaled between.
    ///
    /// Linear would spend most of its range on sizes nobody ships. On this curve 128 pixels,
    /// which is roughly the point an icon stops blurring at 44 points on a 3x screen, lands at
    /// 0.6 rather than at 0.22.
    static func resolutionScore(_ pixelSize: Int?) -> Double {
        guard let pixelSize, pixelSize > 0 else { return 0 }
        let position = (log2(Double(pixelSize)) - 4) / 5
        return min(max(position, 0), 1)
    }
}

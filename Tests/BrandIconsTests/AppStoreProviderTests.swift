import Foundation
import Testing
@testable import BrandIcons

struct AppStoreProviderTests {
    private static let searchPayload = """
    {"resultCount":3,"results":[
      {"trackName":"Netflix","bundleId":"com.netflix.Netflix","trackId":363590051,
       "artworkUrl512":"https://is1-ssl.mzstatic.com/image/thumb/netflix/512x512bb.jpg"},
      {"trackName":"Disney+","bundleId":"com.disney.disneyplus","trackId":1446075923,
       "artworkUrl512":"https://is1-ssl.mzstatic.com/image/thumb/disney/512x512bb.jpg"},
      {"trackName":"Amazon Prime Video","bundleId":"com.amazon.aiv.AIVApp","trackId":545519333,
       "artworkUrl512":"https://is1-ssl.mzstatic.com/image/thumb/amazon/512x512bb.jpg"}
    ]}
    """

    private let network = StubbedNetwork()

    private func provider(isEnabled: Bool = true) -> AppStoreProvider {
        AppStoreProvider(isEnabled: isEnabled, session: network.session)
    }

    @Test func itIsInertUnlessExplicitlyEnabled() async throws {
        network.stub(containing: "itunes.apple.com", with: .json(Self.searchPayload))

        let candidates = try await AppStoreProvider(session: network.session)
            .candidates(for: BrandQuery(name: "Netflix"))

        #expect(candidates.isEmpty)
        #expect(network.requestedURLs.isEmpty)
    }

    @Test func aDisabledProviderRefusesToFetchAPayload() async {
        let candidate = BrandIconCandidate(
            slug: "com.netflix.Netflix",
            title: "Netflix",
            confidence: 1,
            source: .appStore
        )

        await #expect(throws: BrandIconError.providerDisabled(.appStore)) {
            try await AppStoreProvider(session: network.session).shape(for: candidate)
        }
    }

    @Test func itBuildsTheDocumentedSearchQuery() throws {
        let url = try #require(provider().searchURL(for: "Netflix"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        #expect(components.host == "itunes.apple.com")
        #expect(components.path == "/search")
        #expect(items == ["term": "Netflix", "entity": "software", "limit": "3", "country": "US"])
    }

    @Test func itRanksResultsByHowWellTheyMatch() async throws {
        network.stub(containing: "itunes.apple.com/search", with: .json(Self.searchPayload))

        let candidates = try await provider().candidates(for: BrandQuery(name: "Netflix"))

        #expect(candidates.count == 3)
        let best = try #require(candidates.first)
        #expect(best.slug == "com.netflix.Netflix")
        #expect(best.title == "Netflix")
        #expect(best.confidence > 0.9)
        #expect(candidates.map(\.confidence) == candidates.map(\.confidence).sorted(by: >))
    }

    @Test func itFetchesArtworkRememberedFromTheSearch() async throws {
        network.stub(containing: "itunes.apple.com/search", with: .json(Self.searchPayload))
        network.stub(containing: "mzstatic.com/image/thumb/netflix", with: .image())

        let subject = provider()
        let candidates = try await subject.candidates(for: BrandQuery(name: "Netflix"))
        let shape = try await subject.shape(for: try #require(candidates.first))

        #expect(shape == .raster(data: Data([0x89, 0x50, 0x4E, 0x47])))
        #expect(!network.requestedURLs.contains { $0.contains("/lookup") })
    }

    @Test func itFallsBackToTheLookupEndpointForACandidateItDidNotSearchFor() async throws {
        network.stub(
            containing: "itunes.apple.com/lookup",
            with: .json(#"{"resultCount":1,"results":[{"artworkUrl512":"https://is1-ssl.mzstatic.com/netflix.jpg"}]}"#)
        )
        network.stub(containing: "mzstatic.com/netflix.jpg", with: .image())

        let candidate = BrandIconCandidate(
            slug: "com.netflix.Netflix",
            title: "Netflix",
            confidence: 1,
            source: .appStore
        )
        let shape = try await provider().shape(for: candidate)

        #expect(shape == .raster(data: Data([0x89, 0x50, 0x4E, 0x47])))
        #expect(network.requestedURLs.contains { $0.contains("/lookup") })
    }

    @Test func aMissReturnsEmptyRatherThanThrowing() async throws {
        network.stub(containing: "itunes.apple.com", with: .notFound)

        let candidates = try await provider().candidates(for: BrandQuery(name: "Nothing At All"))

        #expect(candidates.isEmpty)
    }

    @Test func anEmptyResultSetIsNotAnError() async throws {
        network.stub(containing: "itunes.apple.com", with: .json(#"{"resultCount":0,"results":[]}"#))

        let candidates = try await provider().candidates(for: BrandQuery(name: "Nothing At All"))

        #expect(candidates.isEmpty)
    }

    @Test func rateLimitingIsReportedRatherThanSwallowed() async {
        network.stub(containing: "itunes.apple.com", with: .init(statusCode: 429))

        await #expect(throws: BrandIconError.rateLimited(retryAfter: nil)) {
            try await provider().candidates(for: BrandQuery(name: "Netflix"))
        }
    }
}

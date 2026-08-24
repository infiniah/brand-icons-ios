import Foundation
import Testing
@testable import BrandIcons

struct FaviconProviderTests {
    private let network = StubbedNetwork()

    private var provider: FaviconProvider {
        FaviconProvider(session: network.session)
    }

    private func candidate(name: String = "Netflix", domain: String = "netflix.com") async throws -> BrandIconCandidate? {
        try await provider.candidates(for: BrandQuery(name: name, domain: domain)).first
    }

    private func payload(_ candidate: BrandIconCandidate?) throws -> Data {
        guard case let .raster(data)? = candidate?.shape else {
            throw TestFailure.notARaster
        }
        return data
    }

    private enum TestFailure: Error { case notARaster }

    @Test func theLargestManifestIconWinsAndArrivesAtThatResolution() async throws {
        network.stub(containing: "/site.webmanifest", with: .json("""
        {"icons":[
          {"src":"/icons/48.png","sizes":"48x48","type":"image/png"},
          {"src":"/icons/512.png","sizes":"512x512","type":"image/png"},
          {"src":"/icons/192.png","sizes":"192x192","type":"image/png"}
        ]}
        """))
        network.stub(containing: "/icons/512.png", with: .png(TestImage.png(side: 512)))
        network.stub(containing: "/icons/192.png", with: .png(TestImage.png(side: 192)))
        network.stub(containing: "/icons/48.png", with: .png(TestImage.png(side: 48)))

        let found = try await candidate()
        let dimensions = try #require(TestImage.dimensions(of: try payload(found)))

        #expect(dimensions.width == 512)
        #expect(dimensions.height == 512)
        #expect(network.requestedURLs.contains("https://netflix.com/icons/512.png"))
        #expect(!network.requestedURLs.contains("https://netflix.com/icons/48.png"))
    }

    @Test func aRelativeSourceResolvesAgainstTheManifestNotTheSiteRoot() async throws {
        network.stub(url: "https://netflix.com/", with: .html("""
        <html><head><link rel="manifest" href="/static/app.webmanifest"></head><body></body></html>
        """))
        network.stub(containing: "/static/app.webmanifest", with: .json("""
        {"icons":[{"src":"icons/icon-192.png","sizes":"192x192","type":"image/png"}]}
        """))
        network.stub(containing: "/static/icons/icon-192.png", with: .png(TestImage.png(side: 192)))

        let found = try await candidate()
        let dimensions = try #require(TestImage.dimensions(of: try payload(found)))

        #expect(dimensions.width == 192)
        #expect(network.requestedURLs.contains("https://netflix.com/static/icons/icon-192.png"))
        #expect(!network.requestedURLs.contains("https://netflix.com/icons/icon-192.png"))
    }

    @Test func aHashedAppleTouchIconIsFoundInTheHead() async throws {
        network.stub(url: "https://netflix.com/", with: .html("""
        <html><head>
          <link rel="icon" href="/favicon.ico" sizes="32x32">
          <link rel="apple-touch-icon" sizes="180x180" href="/assets/apple-touch-icon.a1b2c3d4.png">
        </head><body></body></html>
        """))
        network.stub(containing: "/assets/apple-touch-icon.a1b2c3d4.png", with: .png(TestImage.png(side: 180)))

        let found = try await candidate()
        let dimensions = try #require(TestImage.dimensions(of: try payload(found)))

        #expect(dimensions.width == 180)
        #expect(network.requestedURLs.contains("https://netflix.com/assets/apple-touch-icon.a1b2c3d4.png"))
    }

    @Test func aProtocolRelativeHrefKeepsTheDocumentScheme() async throws {
        network.stub(url: "https://netflix.com/", with: .html("""
        <html><head><link rel='apple-touch-icon' sizes='192x192' href='//cdn.example.com/n/icon.png'></head></html>
        """))
        network.stub(containing: "cdn.example.com/n/icon.png", with: .png(TestImage.png(side: 192)))

        let found = try await candidate()
        let dimensions = try #require(TestImage.dimensions(of: try payload(found)))

        #expect(dimensions.width == 192)
        #expect(network.requestedURLs.contains("https://cdn.example.com/n/icon.png"))
    }

    @Test func markupAfterTheClosingHeadTagIsNotRead() async throws {
        network.stub(url: "https://netflix.com/", with: .html("""
        <html><head>
          <link rel="apple-touch-icon" sizes="180x180" href="/real.png">
        </head><body>
          <link rel="apple-touch-icon" sizes="512x512" href="/decoy.png">
        </body></html>
        """))
        network.stub(containing: "/real.png", with: .png(TestImage.png(side: 180)))
        network.stub(containing: "/decoy.png", with: .png(TestImage.png(side: 512)))

        _ = try await candidate()

        #expect(network.requestedURLs.contains("https://netflix.com/real.png"))
        #expect(!network.requestedURLs.contains("https://netflix.com/decoy.png"))
    }

    @Test func aSiteThatDeclaresNothingStillFallsBackToGuessedPaths() async throws {
        network.stub(containing: "/apple-touch-icon.png", with: .png(TestImage.png(side: 180)))

        let found = try await candidate()
        let dimensions = try #require(TestImage.dimensions(of: try payload(found)))

        #expect(dimensions.width == 180)
        #expect(network.requestedURLs.contains("https://netflix.com/site.webmanifest"))
        #expect(network.requestedURLs.contains("https://netflix.com/manifest.json"))
    }

    @Test func aSiteWithNothingAtAllReturnsEmptyRatherThanThrowing() async throws {
        let candidates = try await provider.candidates(for: BrandQuery(name: "Nope", domain: "nope.example"))

        #expect(candidates.isEmpty)
    }

    @Test func anHTMLErrorPageServedAtAnIconPathIsNotAnIcon() async throws {
        network.stub(containing: "/favicon.ico", with: .html())

        let candidates = try await provider.candidates(for: BrandQuery(name: "Nope", domain: "nope.example"))

        #expect(candidates.isEmpty)
    }

    @Test func aMonochromeMaskIsSkippedForTheRealMark() async throws {
        network.stub(containing: "/site.webmanifest", with: .json("""
        {"icons":[
          {"src":"/mask.png","sizes":"512x512","purpose":"monochrome"},
          {"src":"/mark.png","sizes":"192x192","purpose":"any"}
        ]}
        """))
        network.stub(containing: "/mask.png", with: .png(TestImage.png(side: 512)))
        network.stub(containing: "/mark.png", with: .png(TestImage.png(side: 192)))

        let found = try await candidate()
        let dimensions = try #require(TestImage.dimensions(of: try payload(found)))

        #expect(dimensions.width == 192)
        #expect(!network.requestedURLs.contains("https://netflix.com/mask.png"))
    }

    @Test func aPlainIconBeatsAMaskableOneOfTheSameSize() async throws {
        network.stub(containing: "/site.webmanifest", with: .json("""
        {"icons":[
          {"src":"/maskable.png","sizes":"192x192","purpose":"maskable"},
          {"src":"/plain.png","sizes":"192x192","purpose":"any"}
        ]}
        """))
        network.stub(containing: "/plain.png", with: .png(TestImage.png(side: 192)))
        network.stub(containing: "/maskable.png", with: .png(TestImage.png(side: 192)))

        _ = try await candidate()

        #expect(network.requestedURLs.contains("https://netflix.com/plain.png"))
        #expect(!network.requestedURLs.contains("https://netflix.com/maskable.png"))
    }

    @Test func confidenceRisesWithTheResolutionThatActuallyArrived() async throws {
        let large = StubbedNetwork()
        large.stub(containing: "/site.webmanifest", with: .json(#"{"icons":[{"src":"/i.png","sizes":"512x512"}]}"#))
        large.stub(containing: "/i.png", with: .png(TestImage.png(side: 512)))

        let small = StubbedNetwork()
        small.stub(containing: "/favicon.ico", with: .png(TestImage.png(side: 16)))

        let query = BrandQuery(name: "Netflix", domain: "netflix.com")
        let big = try #require(await FaviconProvider(session: large.session).candidates(for: query).first)
        let tiny = try #require(await FaviconProvider(session: small.session).candidates(for: query).first)

        #expect(big.confidence > tiny.confidence + 0.15)
        #expect(big.confidence <= 0.65)
        #expect(tiny.confidence >= 0.35)
    }

    @Test func anInflatedSizeClaimIsScoredOnWhatArrived() async throws {
        let honest = StubbedNetwork()
        honest.stub(containing: "/site.webmanifest", with: .json(#"{"icons":[{"src":"/i.png","sizes":"512x512"}]}"#))
        honest.stub(containing: "/i.png", with: .png(TestImage.png(side: 512)))

        let lying = StubbedNetwork()
        lying.stub(containing: "/site.webmanifest", with: .json(#"{"icons":[{"src":"/i.png","sizes":"512x512"}]}"#))
        lying.stub(containing: "/i.png", with: .png(TestImage.png(side: 32)))

        let query = BrandQuery(name: "Netflix", domain: "netflix.com")
        let truthful = try #require(await FaviconProvider(session: honest.session).candidates(for: query).first)
        let inflated = try #require(await FaviconProvider(session: lying.session).candidates(for: query).first)

        #expect(inflated.confidence < truthful.confidence)
        #expect(inflated.confidence == FaviconProvider.confidence(match: 1, pixelSize: 32))
    }

    @Test func aWideWordmarkIsScoredOnItsShortSide() async throws {
        network.stub(containing: "/site.webmanifest", with: .json(#"{"icons":[{"src":"/w.png","sizes":"512x512"}]}"#))
        network.stub(containing: "/w.png", with: .png(TestImage.png(width: 512, height: 64)))

        let found = try #require(await candidate())

        #expect(found.confidence == FaviconProvider.confidence(match: 1, pixelSize: 64))
    }

    @Test func theResolutionCurveSpansSixteenToFiveTwelve() {
        #expect(FaviconProvider.resolutionScore(16) == 0)
        #expect(FaviconProvider.resolutionScore(512) == 1)
        #expect(abs(FaviconProvider.resolutionScore(128) - 0.6) < 0.001)
        #expect(FaviconProvider.resolutionScore(nil) == 0)
        #expect(FaviconProvider.resolutionScore(8) == 0)
    }

    @Test func theCeilingHoldsEvenForAPerfectMatchOnAHugeIcon() {
        #expect(FaviconProvider.confidence(match: 1, pixelSize: 4096) == 0.65)
        #expect(FaviconProvider.confidence(match: 0, pixelSize: 512) == 0.35)
    }
}

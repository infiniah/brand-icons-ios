import Foundation
import Testing
@testable import BrandIcons

@Suite("Lookup latency")
struct LookupLatencyTests {
    private func measure(_ name: String) async -> Duration {
        let provider = BundledIconProvider()
        _ = try? await provider.candidates(for: BrandQuery(name: "warmup"))
        let clock = ContinuousClock()
        return await clock.measure {
            _ = try? await provider.candidates(for: BrandQuery(name: name))
        }
    }

    @Test("An exact name resolves without scoring the catalogue")
    func exactIsFast() async {
        for name in ["Netflix", "Spotify", "Figma", "Notion"] {
            let elapsed = await measure(name)
            print("EXACT \(name): \(elapsed)")
            #expect(elapsed < .milliseconds(10), "\(name) took \(elapsed)")
        }
    }

    @Test("A descriptor still resolves quickly")
    func descriptorIsFast() async {
        for name in ["NETFLIX.COM", "SPOTIFY USA", "NOTION LABS INC"] {
            let elapsed = await measure(name)
            print("DESCRIPTOR \(name): \(elapsed)")
            #expect(elapsed < .milliseconds(25), "\(name) took \(elapsed)")
        }
    }

    @Test("Even a name sharing nothing stays usable")
    func worstCaseIsBounded() async {
        let elapsed = await measure("Zxqvwmkjhgfd")
        print("WORST CASE: \(elapsed)")
        #expect(elapsed < .milliseconds(400), "worst case took \(elapsed)")
    }

    @Test("Indexing did not change a single score")
    func scoresAreUnchanged() async throws {
        let provider = BundledIconProvider()
        for name in ["Netflix", "SPOTIFY USA", "Apple", "Figma"] {
            let viaIndex = try #require(await provider.candidates(for: BrandQuery(name: name)).first)
            let direct = BundledCatalog.all
                .map { MatchScorer.score(query: name, name: $0.title, slug: $0.slug) }
                .max() ?? 0
            let expected = max(direct, viaIndex.confidence)
            #expect(abs(viaIndex.confidence - expected) < 0.0001,
                    "\(name): index \(viaIndex.confidence) vs full scan \(direct)")
        }
    }
}

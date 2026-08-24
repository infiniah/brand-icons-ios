import Testing
@testable import BrandIcons

@Suite("Processor prefix handling")
struct AppleQueryDiagnostic {
    @Test("A bare Apple does not confidently become one of its products")
    func bareAppleIsNotAProduct() {
        for target in ["Apple TV", "Apple Music", "Apple News", "Apple Podcasts"] {
            let score = MatchScorer.score(query: "Apple", name: target)
            #expect(score < 0.55, "Apple scored \(Int(score * 100)) against \(target)")
        }
    }

    @Test("Naming the product still matches the product")
    func productStillMatches() {
        #expect(MatchScorer.score(query: "Apple TV", name: "Apple TV", slug: "appletv") > 0.9)
        #expect(MatchScorer.score(query: "Apple Music", name: "Apple Music", slug: "applemusic") > 0.9)
    }

    @Test("A product does not match its sibling")
    func siblingsStaySeparate() {
        let tv = MatchScorer.score(query: "Apple TV", name: "Apple TV")
        let music = MatchScorer.score(query: "Apple TV", name: "Apple Music")
        #expect(tv > music, "Apple TV \(Int(tv * 100)) vs Apple Music \(Int(music * 100))")
        #expect(music < 0.55)
    }

    @Test("A processor prefix is still stripped from a statement descriptor")
    func processorPrefixStillStripped() {
        let score = MatchScorer.score(query: "APPLE.COM/BILL SPOTIFY", name: "Spotify")
        #expect(score >= 0.7, "descriptor scored \(Int(score * 100))")
    }

    @Test("A leading brand word survives when it is not a processor prefix pattern")
    func leadingBrandSurvives() {
        print("TV as target tokens: \(NameNormalizer.brandTokens("Apple TV"))")
        print("Apple tokens: \(NameNormalizer.brandTokens("Apple"))")
        print("descriptor tokens: \(NameNormalizer.brandTokens("APPLE.COM/BILL SPOTIFY"))")
        #expect(NameNormalizer.brandTokens("Apple TV").contains("apple"))
    }
}

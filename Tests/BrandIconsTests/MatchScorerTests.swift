import Testing
@testable import BrandIcons

@Suite("Match scoring")
struct MatchScorerTests {
    @Test("An exact name scores full confidence")
    func exactName() {
        #expect(MatchScorer.score(query: "Netflix", name: "Netflix") == 1.0)
        #expect(MatchScorer.score(query: "netflix", name: "Netflix") == 1.0)
        #expect(MatchScorer.score(query: "NETFLIX", name: "Netflix") == 1.0)
    }

    @Test("A statement descriptor still reaches its brand")
    func statementDescriptors() {
        let cases = [
            ("NETFLIX.COM", "Netflix"),
            ("SPOTIFY USA", "Spotify"),
            ("ADOBE CREATIVE CLOUD", "Adobe Creative Cloud"),
            ("NOTION LABS INC", "Notion")
        ]
        for (descriptor, brand) in cases {
            let score = MatchScorer.score(query: descriptor, name: brand)
            #expect(score >= 0.7, "\(descriptor) scored \(score) against \(brand)")
        }
    }

    @Test("Processor noise does not drown the brand")
    func processorNoise() {
        let score = MatchScorer.score(query: "APPLE.COM/BILL SPOTIFY", name: "Spotify")
        #expect(score >= 0.7)
    }

    @Test("Unrelated brands score low enough to be filtered out")
    func unrelated() {
        #expect(MatchScorer.score(query: "Netflix", name: "Notion") < 0.35)
        #expect(MatchScorer.score(query: "Spotify", name: "Dropbox") < 0.35)
        #expect(MatchScorer.score(query: "Figma", name: "Fitbit") < 0.5)
    }

    @Test("A tier word never collapses two different products into one")
    func tierWordsSeparateProducts() {
        let music = MatchScorer.score(query: "Apple Music", name: "Apple Music")
        let tv = MatchScorer.score(query: "Apple Music", name: "Apple TV")
        #expect(music > tv, "Apple Music scored \(music), Apple TV scored \(tv)")
    }

    @Test("An ambiguous query does not hand one brand a runaway lead")
    func ambiguityIsPreserved() {
        let apple = MatchScorer.score(query: "Apple One", name: "Apple")
        let music = MatchScorer.score(query: "Apple One", name: "Apple Music")
        #expect(abs(apple - music) < 0.35, "apple \(apple) vs apple music \(music)")
    }

    @Test("A slug matches as readily as a display name")
    func slugMatching() {
        let score = MatchScorer.score(query: "1Password", name: "1Password", slug: "1password")
        #expect(score == 1.0)
    }

    @Test("Scores never leave the unit interval")
    func bounded() {
        let queries = ["", "  ", "a", "NETFLIX.COM", "x".repeated(200)]
        for query in queries {
            let score = MatchScorer.score(query: query, name: "Netflix")
            #expect(score >= 0 && score <= 1, "\(query) produced \(score)")
        }
    }

    @Test("Edit distance is symmetric and normalised")
    func editDistance() {
        #expect(MatchScorer.normalizedEditDistance("abc", "abc") == 0)
        #expect(MatchScorer.normalizedEditDistance("abc", "") == 1)
        let forward = MatchScorer.normalizedEditDistance("kitten", "sitting")
        let backward = MatchScorer.normalizedEditDistance("sitting", "kitten")
        #expect(forward == backward)
        #expect(forward > 0 && forward < 1)
    }
}

private extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}

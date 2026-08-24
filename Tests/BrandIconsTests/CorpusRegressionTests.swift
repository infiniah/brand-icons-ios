import Testing
@testable import BrandIcons

/// The two defects the golden corpus surfaced the first time it was exported.
///
/// Both were invisible to the hand written tests because both produce a *plausible* answer:
/// the right brand listed twice, and a real catalogue entry at a real score.
@Suite("Corpus regressions")
struct CorpusRegressionTests {
    @Test("A mark is never returned twice for one query")
    func noDuplicateMarks() async throws {
        let provider = BundledIconProvider()
        for query in ["Apple", "X", "Meta", "Netflix", "Figma", "Spotify"] {
            let slugs = try await provider.candidates(for: BrandQuery(name: query)).map(\.slug)
            #expect(slugs.count == Set(slugs).count, "\(query) returned a duplicate: \(slugs)")
        }
    }

    @Test("A single letter brand is not contained in every descriptor")
    func singleLetterBrandsDoNotMatchEverything() {
        #expect(MatchScorer.score(query: "SQ *BLUE BOTTLE", name: "E") == 0)
        #expect(MatchScorer.score(query: "netflix.com", name: "X") == 0)
    }

    @Test("Containment still carries the case it exists for")
    func containmentStillWorks() {
        #expect(MatchScorer.score(query: "netflixcom", name: "Netflix") > 0.4)
    }
}

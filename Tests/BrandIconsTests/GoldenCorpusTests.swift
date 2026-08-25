import Foundation
import Testing
@testable import BrandIcons

/// Holds the reference port to the same contract the other three are held to.
///
/// `GoldenCorpusExport` writes this file and every port is checked against it. Swift was the one
/// port that only wrote it, so a change here could not fail until Kotlin, Dart or TypeScript ran.
@Suite("Golden corpus verification")
struct GoldenCorpusTests {
    struct Row: Decodable {
        let query: String
        let normalizedKey: String
        let brandTokens: [String]
        let candidates: [Candidate]
    }

    struct Candidate: Decodable {
        let slug: String
        let confidence: Double
    }

    static let reference: [Row] = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/golden-corpus.json")
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Row].self, from: data)
        else { return [] }
        return rows
    }()

    @Test("Normalises identically to the reference")
    func normalises() {
        #expect(!Self.reference.isEmpty)
        for row in Self.reference {
            #expect(NameNormalizer.key(row.query) == row.normalizedKey, "key for \(row.query)")
            #expect(
                NameNormalizer.brandTokens(row.query) == row.brandTokens,
                "brand tokens for \(row.query)"
            )
        }
    }

    @Test("Scores identically to the reference")
    func scores() async throws {
        let provider = BundledIconProvider()
        for row in Self.reference {
            let found = try await provider.candidates(for: BrandQuery(name: row.query)).prefix(5)
            #expect(
                found.map(\.slug) == row.candidates.map(\.slug),
                "candidates for \(row.query)"
            )
            for (candidate, expected) in zip(found, row.candidates) {
                #expect(
                    abs(candidate.confidence - expected.confidence) < 0.0001,
                    "confidence for \(row.query) / \(expected.slug)"
                )
            }
        }
    }

    @Test("Is the catalogue the corpus was generated from")
    func catalogueMatches() {
        #expect(BundledCatalog.all.count == 4770)
    }
}

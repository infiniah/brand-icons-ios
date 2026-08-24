import Foundation
import Testing
@testable import BrandIcons

/// Writes the reference behaviour every port must reproduce.
///
/// Run with `BRANDICONS_EXPORT_GOLDEN=1 swift test --filter GoldenCorpusExport`.
/// Skipped otherwise, because it writes outside the package.
@Suite("Golden corpus")
struct GoldenCorpusExport {
    static let queries = [
        "Netflix", "NETFLIX.COM", "netflix", "Spotify", "SPOTIFY USA",
        "APPLE.COM/BILL SPOTIFY", "Apple", "Apple TV", "Apple Music",
        "Notion", "NOTION LABS INC", "Figma", "Adobe Creative Cloud",
        "1Password", "Duolingo", "GitHub", "Slack", "Dropbox", "Vue.js",
        "Zxqvwmkjhgfd", "", "a", "  ", "Amazon", "Google", "Microsoft",
        "X", "Meta", "Discord", "Twitch", "Steam", "PlayStation",
        "SQ *BLUE BOTTLE", "PAYPAL *SPOTIFY", "Disney+", "HBO Max"
    ]

    @Test("Export the reference scores")
    func export() async throws {
        guard ProcessInfo.processInfo.environment["BRANDICONS_EXPORT_GOLDEN"] == "1" else { return }

        struct Row: Encodable {
            let query: String
            let normalizedKey: String
            let brandTokens: [String]
            let candidates: [Candidate]
        }
        struct Candidate: Encodable {
            let slug: String
            let confidence: Double
        }

        let provider = BundledIconProvider()
        var rows: [Row] = []

        for query in Self.queries {
            let found = ((try? await provider.candidates(for: BrandQuery(name: query))) ?? [])
                .prefix(5)
                .map { Candidate(slug: $0.slug, confidence: ($0.confidence * 10000).rounded() / 10000) }
            rows.append(
                Row(
                    query: query,
                    normalizedKey: NameNormalizer.key(query),
                    brandTokens: NameNormalizer.brandTokens(query),
                    candidates: Array(found)
                )
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("golden-corpus.json")
        try encoder.encode(rows).write(to: url)
        print("GOLDEN WRITTEN: \(url.path)")
    }
}

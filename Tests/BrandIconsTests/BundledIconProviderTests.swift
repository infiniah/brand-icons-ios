import CoreGraphics
import Foundation
import Testing
@testable import BrandIcons

struct BundledIconProviderTests {
    private static let marks = [
        BundledMark(
            slug: "netflix",
            title: "Netflix",
            pathData: "M5 0h4l6 24H11z",
            viewBox: CGRect(x: 0, y: 0, width: 24, height: 24),
            tint: BrandColor(red: 229, green: 9, blue: 20)
        ),
        BundledMark(
            slug: "spotify",
            title: "Spotify",
            pathData: "M12 0a12 12 0 100 24 12 12 0 000-24z",
            viewBox: CGRect(x: 0, y: 0, width: 24, height: 24),
            tint: BrandColor(red: 30, green: 215, blue: 96)
        ),
        BundledMark(
            slug: "notion",
            title: "Notion",
            pathData: "M4 4h16v16H4z",
            viewBox: CGRect(x: 0, y: 0, width: 24, height: 24),
            tint: BrandColor.black
        )
    ]

    private var provider: BundledIconProvider {
        BundledIconProvider(marks: Self.marks)
    }

    @Test func itMatchesAMessyStatementDescriptor() async throws {
        let candidates = try await provider.candidates(for: BrandQuery(name: "NETFLIX.COM"))

        let best = try #require(candidates.first)
        #expect(best.slug == "netflix")
        #expect(best.confidence > 0.9)
        #expect(best.shape == .vector(
            path: "M5 0h4l6 24H11z",
            viewBox: CGRect(x: 0, y: 0, width: 24, height: 24),
            tint: BrandColor(red: 229, green: 9, blue: 20)
        ))
    }

    @Test func unrelatedMarksAreDroppedBelowTheFloor() async throws {
        let candidates = try await provider.candidates(for: BrandQuery(name: "Netflix"))

        #expect(candidates.allSatisfy { $0.confidence > 0.3 })
        #expect(!candidates.contains { $0.slug == "spotify" })
    }

    @Test func candidatesComeBackSorted() async throws {
        let candidates = try await provider.candidates(for: BrandQuery(name: "Spotify Premium"))
        #expect(candidates.map(\.confidence) == candidates.map(\.confidence).sorted(by: >))
        #expect(candidates.first?.slug == "spotify")
    }

    @Test func nothingMatchesReturnsEmpty() async throws {
        let candidates = try await provider.candidates(for: BrandQuery(name: "Zzyzx Municipal Water"))
        #expect(candidates.isEmpty)
    }

    @Test func itResolvesAPayloadForABareCandidate() async throws {
        let bare = BrandIconCandidate(slug: "notion", title: "Notion", confidence: 1, source: .bundled)
        let shape = try await provider.shape(for: bare)
        #expect(shape.isVector)
    }

    @Test func anUnknownSlugIsNotFound() async {
        let bare = BrandIconCandidate(slug: "nope", title: "Nope", confidence: 1, source: .bundled)
        await #expect(throws: BrandIconError.notFound) {
            try await provider.shape(for: bare)
        }
    }
}

import Testing
@testable import BrandIcons

@Suite("Source preference")
struct SourcePreferenceTests {
    @Test("Enabling the App Store prefers it, because that is why you enabled it")
    func appStoreImpliesPreference() {
        #expect(ResolverConfiguration(allowsAppStore: true).effectivePreferredSources == [.appStore])
        #expect(ResolverConfiguration(allowsAppStore: false).effectivePreferredSources.isEmpty)
    }

    @Test("An explicit list overrides the derived one, including an empty list")
    func explicitListWins() {
        let ranked = ResolverConfiguration(allowsAppStore: true, preferredSources: [.favicon])
        #expect(ranked.effectivePreferredSources == [.favicon])

        let none = ResolverConfiguration(allowsAppStore: true, preferredSources: [])
        #expect(none.effectivePreferredSources.isEmpty)
    }

    @Test("A preferred source outranks a more confident candidate from elsewhere")
    func preferenceBeatsConfidence() {
        let result = BrandIconResult(
            query: "Figma",
            candidates: [
                .init(slug: "figma", title: "Figma", confidence: 1.0, source: .bundled),
                .init(slug: "figma", title: "Figma", confidence: 0.78, source: .appStore)
            ],
            preferring: [.appStore]
        )
        #expect(result.candidates.first?.source == .appStore)
        #expect(result.candidates.last?.source == .bundled)
    }

    @Test("Within one source, confidence still decides")
    func confidenceDecidesWithinASource() {
        let result = BrandIconResult(
            query: "Apple",
            candidates: [
                .init(slug: "appletv", title: "Apple TV", confidence: 0.51, source: .bundled),
                .init(slug: "apple", title: "Apple", confidence: 0.94, source: .bundled)
            ],
            preferring: [.appStore]
        )
        #expect(result.candidates.map(\.title) == ["Apple", "Apple TV"])
    }
}

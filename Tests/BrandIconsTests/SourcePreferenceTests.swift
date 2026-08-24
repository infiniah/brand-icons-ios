import Testing
@testable import BrandIcons

@Suite("Source preference")
struct SourcePreferenceTests {
    @Test("Real artwork tiers are preferred, best artwork first")
    func realArtworkIsPreferred() {
        #expect(
            ResolverConfiguration(allowsAppStore: true).effectivePreferredSources
                == [.appStore, .favicon]
        )
        #expect(
            ResolverConfiguration(allowsAppStore: false).effectivePreferredSources == [.favicon]
        )
    }

    @Test("Offline prefers nothing, because there is nothing to prefer")
    func offlinePrefersNothing() {
        #expect(ResolverConfiguration.offline.effectivePreferredSources.isEmpty)
    }

    @Test("An unsure preferred source does not jump the queue")
    func thresholdGatesPreference() {
        // The exact case this exists for: a favicon scraped off a domain guessed from the name
        // must not displace a certain catalogue match. Trading a dull icon for a wrong one is
        // not an improvement.
        let result = BrandIconResult(
            query: "Figma",
            candidates: [
                .init(slug: "figma", title: "Figma", confidence: 1.0, source: .bundled),
                .init(slug: "figma.com", title: "Figma", confidence: 0.65, source: .favicon)
            ],
            preferring: [.favicon]
        )
        #expect(result.candidates.first?.source == .bundled)
    }

    @Test("A confident preferred source does jump the queue")
    func confidentPreferenceWins() {
        let result = BrandIconResult(
            query: "Figma",
            candidates: [
                .init(slug: "figma", title: "Figma", confidence: 1.0, source: .bundled),
                .init(slug: "figma.com", title: "Figma", confidence: 0.86, source: .favicon)
            ],
            preferring: [.favicon]
        )
        #expect(result.candidates.first?.source == .favicon)
    }

    @Test("An explicit list overrides the derived one, including an empty list")
    func explicitListWins() {
        let ranked = ResolverConfiguration(allowsAppStore: true, preferredSources: [.favicon])
        #expect(ranked.effectivePreferredSources == [.favicon])

        let none = ResolverConfiguration(allowsAppStore: true, preferredSources: [])
        #expect(none.effectivePreferredSources.isEmpty)
    }

    @Test("Bundled never loses to a source that found nothing worth trusting")
    func bundledSurvivesWeakNetworkAnswers() {
        let result = BrandIconResult(
            query: "Spotify",
            candidates: [
                .init(slug: "spotify", title: "Spotify", confidence: 1.0, source: .bundled),
                .init(slug: "spotify.com", title: "Spotify", confidence: 0.41, source: .favicon)
            ],
            preferring: [.favicon]
        )
        #expect(result.candidates.map(\.source) == [.bundled, .favicon])
    }

    @Test("A preferred source outranks a more confident candidate from elsewhere")
    func preferenceBeatsConfidence() {
        // Figma is the case this whole mechanism exists for. Simple Icons draws it as a hollow
        // outline built from paired loops, so the bundled mark is certainly the right brand and
        // is not what anyone recognises as the logo. The App Store has the real five colour icon.
        let result = BrandIconResult(
            query: "Figma",
            candidates: [
                .init(slug: "figma", title: "Figma", confidence: 1.0, source: .bundled),
                .init(slug: "com.figma.FigmaMirror", title: "Figma", confidence: 1.0, source: .appStore)
            ],
            preferring: [.appStore]
        )
        #expect(result.candidates.first?.source == .appStore)
        #expect(result.candidates.last?.source == .bundled)
    }

    @Test("Preference is not a licence to be wrong")
    func preferenceStillNeedsToBeSure() {
        // Same shape as above but the store was unsure, which is what a store search for a name
        // it does not carry looks like. The catalogue match keeps the top slot.
        let result = BrandIconResult(
            query: "Figma",
            candidates: [
                .init(slug: "figma", title: "Figma", confidence: 1.0, source: .bundled),
                .init(slug: "com.other.app", title: "Figma Tools", confidence: 0.78, source: .appStore)
            ],
            preferring: [.appStore]
        )
        #expect(result.candidates.first?.source == .bundled)
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

import Foundation

/// How the resolver should behave.
public struct ResolverConfiguration: Sendable {
    /// Stop as soon as a candidate reaches this confidence, without asking slower providers.
    public var shortCircuitConfidence: Double

    /// Candidates below this are discarded rather than returned.
    public var minimumConfidence: Double

    /// Most candidates to return.
    public var maximumCandidates: Int

    /// Whether the App Store provider may be used.
    ///
    /// Off by default, deliberately. Apple's Search API is limited to roughly twenty calls
    /// a minute per client, and its terms describe that artwork as promotional material for
    /// store content shown near a store badge. Using it to label a row in your own UI is a
    /// judgement you should make knowingly, so this package will not make it for you.
    public var allowsAppStore: Bool

    /// Whether providers that need the network may be used at all.
    public var allowsNetwork: Bool

    /// Requests per minute allowed per provider.
    public var requestsPerMinute: Int

    /// Sources that win over a higher scoring candidate from somewhere else.
    ///
    /// Confidence answers "is this the right brand". It says nothing about whether the artwork
    /// is any good, and those come apart badly. The bundled catalogue is Simple Icons, which is
    /// a monochrome single path set by design, so Figma's five coloured shapes and Duolingo's
    /// owl both flatten to white outlines. Both score 1.00, because they are unambiguously the
    /// right brand, and both look nothing like the logo people recognise.
    ///
    /// The App Store returns the real thing in colour. Listing it here lets a caller say "if the
    /// store knows this app, draw the store's icon", while still falling back to a flattened mark
    /// rather than to nothing.
    ///
    /// Order matters: earlier wins. A preferred candidate must still clear
    /// ``minimumConfidence`` to be picked, so preferring a source never means accepting a bad
    /// match from it.
    ///
    /// Leaving this `nil` derives it from what is enabled: every tier that returns real artwork,
    /// best first. Set it explicitly, including to `[]`, to rank purely on confidence.
    public var preferredSources: [BrandIconSource]?

    /// How sure a preferred source must be before it may jump the queue.
    ///
    /// Without a bar, preference would be actively harmful. The favicon tier answers for a domain
    /// guessed from the name, so `Acme Corp` cheerfully returns whatever `acmecorp.com` happens to
    /// serve, and letting that outrank a certain catalogue match would trade a dull icon for a
    /// wrong one.
    ///
    /// At the default, App Store artwork for a name it matched exactly wins, and a favicon scraped
    /// off a guessed domain does not. A favicon *does* win once you pass a real ``BrandQuery/domain``,
    /// because then it is the brand's own declared icon and nothing beats that.
    public var preferenceThreshold: Double

    /// The ordering actually applied, after deriving it from what is enabled.
    ///
    /// Ordered by how good the artwork tends to be rather than by how fast the tier is: App Store
    /// icons are designed at 512 points, and a favicon is whatever the site had lying around.
    public var effectivePreferredSources: [BrandIconSource] {
        if let preferredSources { return preferredSources }
        guard allowsNetwork else { return [] }
        var derived: [BrandIconSource] = []
        if allowsAppStore { derived.append(.appStore) }
        derived.append(.favicon)
        return derived
    }

    /// Leaves out marks whose recorded terms forbid commercial use or derivative works.
    ///
    /// Thirteen marks in the generated catalogue carry NonCommercial or NoDerivatives terms,
    /// among them `vuedotjs`, `sass`, `cocoapods` and `letsencrypt`. NonCommercial conflicts
    /// with shipping a paid app. NoDerivatives sits awkwardly with what this package does to
    /// every mark, which is reparse its path and rescale it.
    ///
    /// The default is `false`, matching what Simple Icons itself ships, because excluding
    /// marks silently would make the catalogue quietly worse and hide a decision that belongs
    /// to you. Turn it on if your app is paid, or if you would rather not have the argument.
    /// Either way, read NOTICE.
    public var excludesRestrictiveLicenses: Bool

    public init(
        shortCircuitConfidence: Double = 0.95,
        minimumConfidence: Double = 0.35,
        maximumCandidates: Int = 5,
        allowsAppStore: Bool = false,
        allowsNetwork: Bool = true,
        requestsPerMinute: Int = 15,
        excludesRestrictiveLicenses: Bool = false,
        preferredSources: [BrandIconSource]? = nil,
        preferenceThreshold: Double = 0.8
    ) {
        self.shortCircuitConfidence = shortCircuitConfidence
        self.minimumConfidence = minimumConfidence
        self.maximumCandidates = maximumCandidates
        self.allowsAppStore = allowsAppStore
        self.allowsNetwork = allowsNetwork
        self.requestsPerMinute = requestsPerMinute
        self.excludesRestrictiveLicenses = excludesRestrictiveLicenses
        self.preferredSources = preferredSources
        self.preferenceThreshold = preferenceThreshold
    }

    /// Bundled marks only. No network, no third party, works on a plane.
    public static let offline = ResolverConfiguration(allowsNetwork: false)

    /// Asks every provider and never stops early.
    ///
    /// The default configuration stops as soon as a candidate is good enough, which is what
    /// you want in production and exactly wrong when you are comparing tiers. Use this to see
    /// what each provider would have said for the same query, at the cost of a request to all
    /// of them.
    public static let exhaustive = ResolverConfiguration(
        shortCircuitConfidence: 2,
        minimumConfidence: 0,
        maximumCandidates: 12
    )

    public static let `default` = ResolverConfiguration()
}

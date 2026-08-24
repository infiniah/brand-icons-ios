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
        excludesRestrictiveLicenses: Bool = false
    ) {
        self.shortCircuitConfidence = shortCircuitConfidence
        self.minimumConfidence = minimumConfidence
        self.maximumCandidates = maximumCandidates
        self.allowsAppStore = allowsAppStore
        self.allowsNetwork = allowsNetwork
        self.requestsPerMinute = requestsPerMinute
        self.excludesRestrictiveLicenses = excludesRestrictiveLicenses
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

import Foundation

/// Where a candidate came from. Callers use this to decide how much to trust a result,
/// and to honour the terms attached to a particular provider.
public enum BrandIconSource: String, Hashable, Sendable, CaseIterable {
    /// Vector paths compiled into the package. No network, works offline.
    case bundled

    /// The service's own site, via its apple-touch-icon or favicon.
    case favicon

    /// App Store artwork. Off by default: see `ResolverConfiguration.allowsAppStore`.
    case appStore

    /// Whether resolving from this source requires a network call.
    public var needsNetwork: Bool { self != .bundled }
}

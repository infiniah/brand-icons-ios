import Foundation

public enum BrandIconError: Error, Hashable, Sendable {
    /// The provider answered, but had nothing for this query.
    case notFound

    /// The provider answered with something this package could not read.
    case unreadableResponse

    /// The provider asked us to slow down. Carries the delay it suggested, when it gave one.
    case rateLimited(retryAfter: TimeInterval?)

    /// The provider is disabled by configuration.
    case providerDisabled(BrandIconSource)

    case transport(String)
}

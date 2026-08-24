import Foundation

/// What the caller knows about the thing it wants an icon for.
///
/// Only ``name`` is required. Supplying ``domain`` markedly improves both accuracy and
/// speed, because domain lookups are exact where name lookups are fuzzy.
public struct BrandQuery: Hashable, Sendable {
    /// Free text, as it appears to the user or on a statement.
    public let name: String

    /// The service's website host, without scheme, when known. `netflix.com`.
    public let domain: String?

    /// A hint that the caller already knows the canonical slug.
    public let slug: String?

    public init(name: String, domain: String? = nil, slug: String? = nil) {
        self.name = name
        self.domain = domain.map(BrandQuery.normalizeDomain)
        self.slug = slug
    }

    /// A domain guessed from the name, used when the caller did not supply one.
    ///
    /// This is deliberately naive. It is a guess, and providers that use it should treat a
    /// miss as ordinary rather than as an error.
    public var inferredDomain: String {
        domain ?? "\(NameNormalizer.key(name)).com"
    }

    static func normalizeDomain(_ raw: String) -> String {
        var value = raw.lowercased()
        for prefix in ["https://", "http://", "www."] where value.hasPrefix(prefix) {
            value = String(value.dropFirst(prefix.count))
        }
        if let slash = value.firstIndex(of: "/") { value = String(value[value.startIndex..<slash]) }
        return value
    }
}

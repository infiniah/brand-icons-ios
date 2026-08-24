import Foundation

/// One possible answer to a lookup, with how much the resolver believes it.
///
/// The resolver always returns candidates sorted by descending ``confidence``. A caller
/// that wants a single answer asks for ``BrandIconResult/best(minimum:)``; a caller that
/// wants to let a person choose shows the whole list. Both are first class, because
/// "Apple One", "Amazon" and "Office" genuinely have more than one right answer.
public struct BrandIconCandidate: Hashable, Sendable, Identifiable {
    /// Stable identity for the brand, usually a Simple Icons slug or a domain.
    public let slug: String

    /// Human readable brand name, suitable for showing in a disambiguation list.
    public let title: String

    /// How strongly the query matched this brand, 0 to 1.
    public let confidence: Double

    /// Which provider produced it.
    public let source: BrandIconSource

    /// The drawable payload, if it has been fetched. Bundled candidates always carry one;
    /// network candidates may be resolved lazily.
    public let shape: BrandIconShape?

    public var id: String { "\(source.rawValue):\(slug)" }

    public init(
        slug: String,
        title: String,
        confidence: Double,
        source: BrandIconSource,
        shape: BrandIconShape? = nil
    ) {
        self.slug = slug
        self.title = title
        self.confidence = min(max(confidence, 0), 1)
        self.source = source
        self.shape = shape
    }

    /// A copy carrying a freshly fetched payload.
    public func withShape(_ shape: BrandIconShape) -> BrandIconCandidate {
        BrandIconCandidate(
            slug: slug,
            title: title,
            confidence: confidence,
            source: source,
            shape: shape
        )
    }
}

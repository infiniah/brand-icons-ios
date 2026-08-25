import Foundation

/// The marks compiled into the package.
///
/// Costs no network and cannot be rate limited, so the resolver asks it first and often never
/// asks anything else. Every mark is scored against the query, and everything that clears a
/// low floor is returned rather than only the winner, because the caller may want to show a
/// chooser when two brands score alike.
public struct BundledIconProvider: BrandIconProvider {
    public let source: BrandIconSource = .bundled

    /// Below this a mark is noise rather than a weak answer.
    static let floor = 0.3

    private let marks: [BundledMark]
    private let index: MarkIndex

    /// - Parameter marks: Defaults to the compiled catalog. Injected in tests, and by an
    ///   adopter that ships its own marks instead of or alongside the generated ones.
    public init(marks: [BundledMark] = BundledCatalog.all) {
        self.marks = marks
        index = MarkIndex(marks: marks)
    }

    public func candidates(for query: BrandQuery) async throws -> [BrandIconCandidate] {
        // An exact key match cannot be beaten, so scoring the rest of the catalogue to
        // discover that is wasted work on every common name.
        let exact = index.exactMatches(for: query.name)
        if !exact.isEmpty {
            return exact.map { candidate(for: $0, confidence: 1) }
        }

        return index
            .shortlist(for: query.name)
            .map { mark in
                BrandIconCandidate(
                    slug: mark.slug,
                    title: mark.title,
                    confidence: MatchScorer.score(query: query.name, name: mark.title, slug: mark.slug),
                    source: source,
                    shape: Self.shape(for: mark)
                )
            }
            .filter { $0.confidence > Self.floor }
            .sorted { $0.confidence > $1.confidence }
    }

    private func candidate(for mark: BundledMark, confidence: Double) -> BrandIconCandidate {
        BrandIconCandidate(
            slug: mark.slug,
            title: mark.title,
            confidence: confidence,
            source: source,
            shape: Self.shape(for: mark)
        )
    }

    /// The colour artwork when the brand has it, and the flattened mark otherwise.
    ///
    /// `pathData` on a mark that also has layers is the silhouette of the same brand, kept as a
    /// fallback for a caller that wants one tint it can recolour.
    public static func shape(for mark: BundledMark) -> BrandIconShape {
        if let colorViewBox = mark.colorViewBox, !mark.layers.isEmpty {
            return .layeredVector(layers: mark.layers, viewBox: colorViewBox)
        }
        return .vector(path: mark.pathData, viewBox: mark.viewBox, tint: mark.tint)
    }

    public func shape(for candidate: BrandIconCandidate) async throws -> BrandIconShape {
        if let shape = candidate.shape { return shape }
        guard let mark = marks.first(where: { $0.slug == candidate.slug }) else {
            throw BrandIconError.notFound
        }
        return Self.shape(for: mark)
    }
}

import BrandIcons
import Observation

@MainActor
@Observable
final class MarksModel {
    var query: String = "" { didSet { refilter() } }
    var facet: MarkFacet = .all { didSet { refilter() } }
    var variant: CatalogVariant = .full { didSet { reload() } }

    private(set) var visible: [BundledMark] = []
    private var faceted: [BundledMark] = []

    init(query: String = "") {
        self.query = query
        reload()
    }

    var total: Int { BundledCatalog.marks(variant).count }

    var summary: String {
        let all = BundledCatalog.marks(variant)
        let colour = all.count { !$0.layers.isEmpty }
        return "\(all.count.formatted()) brands · \(colour.formatted()) in colour"
    }

    private func reload() {
        faceted = BundledCatalog.marks(variant).filter(facet.contains)
        applyQuery()
    }

    private func refilter() {
        faceted = BundledCatalog.marks(variant).filter(facet.contains)
        applyQuery()
    }

    /// Substring first, because a browser is a filter and the answer to `spo` is every mark
    /// containing it. The scorer only runs when that finds nothing, which is the case a
    /// misspelling produces: it shares no substring and edit distance is what catches it.
    private func applyQuery() {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else {
            visible = faceted
            return
        }

        let literal = faceted
            .compactMap { mark -> (BundledMark, Int)? in
                guard let rank = Self.rank(mark, needle) else { return nil }
                return (mark, rank)
            }
            .sorted { $0.1 == $1.1 ? $0.0.slug < $1.0.slug : $0.1 < $1.1 }
        if !literal.isEmpty {
            visible = literal.map(\.0)
            return
        }

        visible = faceted
            .map { ($0, MatchScorer.score(query: needle, name: $0.title, slug: $0.slug)) }
            .filter { $0.1 >= 0.35 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// Lower sorts first. A name that starts with what was typed is what the typist meant, so
    /// `spo` puts Spotify above Diaspora rather than leaving it to the alphabet.
    private static func rank(_ mark: BundledMark, _ needle: String) -> Int? {
        let title = mark.title.lowercased()
        if mark.slug.hasPrefix(needle) { return 0 }
        if title.hasPrefix(needle) { return 1 }
        if mark.slug.contains(needle) { return 2 }
        if title.contains(needle) { return 3 }
        return nil
    }
}

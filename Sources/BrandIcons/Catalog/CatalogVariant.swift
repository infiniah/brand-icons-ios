import Foundation

/// Which set of marks to load.
///
/// The two differ only in which marks they contain. Scoring, ranking and the whole API are the
/// same either way, so a query that resolves in one resolves the same in the other unless the
/// brand it names is one of the marks `compact` leaves out.
public enum CatalogVariant: String, Sendable, CaseIterable {
    /// Every mark, 4,770 of them.
    case full

    /// 4,473 marks, leaving out those whose path data runs past 4 KB.
    ///
    /// Those are illustrations rather than icons, indistinct at the size an icon is drawn, and
    /// they account for most of the difference in size.
    case compact

    var resourceName: String {
        switch self {
        case .full: "BrandMarks"
        case .compact: "BrandMarksCompact"
        }
    }
}

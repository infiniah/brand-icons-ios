import CoreGraphics
import Foundation

/// One vector mark compiled into the package.
public struct BundledMark: Hashable, Sendable {
    /// Stable identity, usually a Simple Icons slug.
    public let slug: String

    /// Human readable brand name.
    public let title: String

    /// SVG path data in the coordinate space of ``viewBox``.
    public let pathData: String

    /// The coordinate space ``pathData`` is drawn in.
    public let viewBox: CGRect

    /// The brand's own colour.
    public let tint: BrandColor

    /// The licence Simple Icons records for this icon, when it records one.
    ///
    /// Nil means Simple Icons has nothing on file, which is not the same as the icon being
    /// CC0. See NOTICE.
    public let license: BundledMarkLicense?

    public init(
        slug: String,
        title: String,
        pathData: String,
        viewBox: CGRect,
        tint: BrandColor,
        license: BundledMarkLicense? = nil
    ) {
        self.slug = slug
        self.title = title
        self.pathData = pathData
        self.viewBox = viewBox
        self.tint = tint
        self.license = license
    }
}

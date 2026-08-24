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

    /// The brand's real artwork, when a multi colour rendition exists for it.
    ///
    /// Empty for most marks: Simple Icons is monochrome and only 973 of the catalogue have a
    /// colour counterpart in the SVG Logos set. When it is present it is what should be drawn,
    /// because ``pathData`` is the flattened silhouette of the same brand.
    public let layers: [VectorLayer]

    /// The coordinate space ``layers`` are drawn in, which is not ``viewBox``.
    ///
    /// The two sets do not agree on a canvas: Simple Icons normalises everything to 24 by 24,
    /// and SVG Logos keeps each mark's own proportions.
    public let colorViewBox: CGRect?

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
        layers: [VectorLayer] = [],
        colorViewBox: CGRect? = nil,
        license: BundledMarkLicense? = nil
    ) {
        self.slug = slug
        self.title = title
        self.pathData = pathData
        self.viewBox = viewBox
        self.tint = tint
        self.layers = layers
        self.colorViewBox = colorViewBox
        self.license = license
    }
}

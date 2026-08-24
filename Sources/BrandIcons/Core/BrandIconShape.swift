import CoreGraphics
import Foundation

/// The drawable payload of a resolved icon.
///
/// Vector marks are the fast path: they arrive as an SVG path, are parsed once into a
/// `CGPath`, and cost nothing to rasterise at any size. Raster marks carry image bytes
/// because some providers only offer bitmaps.
public enum BrandIconShape: Hashable, Sendable {
    /// A single filled path in its own coordinate space.
    case vector(path: String, viewBox: CGRect, tint: BrandColor)

    /// Several filled paths in one coordinate space, painted in order.
    ///
    /// This is what a brand whose logo is genuinely multi colour needs. See ``VectorLayer``.
    case layeredVector(layers: [VectorLayer], viewBox: CGRect)

    /// Encoded image data, typically PNG.
    case raster(data: Data)

    public var isVector: Bool {
        switch self {
        case .vector, .layeredVector: true
        case .raster: false
        }
    }

    /// True when the mark carries the brand's real colours rather than one flat tint.
    public var isMultiColor: Bool {
        guard case let .layeredVector(layers, _) = self else { return false }
        return Set(layers.compactMap(\.fill)).count > 1
    }
}

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

    /// Encoded image data, typically PNG.
    case raster(data: Data)

    public var isVector: Bool {
        if case .vector = self { return true }
        return false
    }
}

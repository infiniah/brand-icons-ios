import CoreGraphics
import Foundation

public extension BrandIconShape {
    /// The mark as a `CGPath` in its own `viewBox` coordinate space.
    ///
    /// A multi colour mark comes back as the union of its layers, which is the silhouette rather
    /// than the artwork: colour cannot survive a single path. Draw ``BrandIconView`` for the real
    /// thing, and use this when you want one shape to clip or mask with.
    ///
    /// Nil for a raster shape, and for vector data this package cannot read.
    var cgPath: CGPath? {
        switch self {
        case let .vector(data, _, _):
            return SVGPathParser.path(from: data)
        case let .layeredVector(layers, _):
            let union = CGMutablePath()
            for layer in layers {
                guard let part = SVGPathParser.path(from: layer.path) else { continue }
                union.addPath(part)
            }
            return union.isEmpty ? nil : union.copy()
        case .raster:
            return nil
        }
    }

    /// The coordinate space this shape is drawn in.
    var viewBox: CGRect? {
        switch self {
        case let .vector(_, box, _): box
        case let .layeredVector(_, box): box
        case .raster: nil
        }
    }

    /// The mark as a `CGPath` scaled to fit `rect`, keeping its aspect ratio and centred.
    ///
    /// The `viewBox` origin is honoured, so a mark drawn in a shifted box lands where it
    /// should. y grows downwards, matching UIKit and SwiftUI.
    ///
    /// ```swift
    /// let path = shape.cgPath(fitting: CGRect(x: 0, y: 0, width: 44, height: 44))
    /// ```
    func cgPath(fitting rect: CGRect) -> CGPath? {
        guard let viewBox, viewBox.width > 0, viewBox.height > 0,
              rect.width > 0, rect.height > 0,
              let path = cgPath
        else { return nil }

        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let width = viewBox.width * scale
        let height = viewBox.height * scale

        var transform = CGAffineTransform.identity
            .translatedBy(x: rect.midX - width / 2, y: rect.midY - height / 2)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -viewBox.minX, y: -viewBox.minY)

        return path.copy(using: &transform)
    }
}

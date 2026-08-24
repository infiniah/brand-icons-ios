import CoreGraphics
import Foundation

public extension BrandIconShape {
    /// The mark as a `CGPath` in its own `viewBox` coordinate space.
    ///
    /// Nil for a raster shape, and for vector data this package cannot read.
    var cgPath: CGPath? {
        guard case let .vector(data, _, _) = self else { return nil }
        return SVGPathParser.path(from: data)
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
        guard case let .vector(data, viewBox, _) = self,
              viewBox.width > 0, viewBox.height > 0,
              rect.width > 0, rect.height > 0,
              let path = SVGPathParser.path(from: data)
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

import Foundation

#if canImport(ImageIO)
import ImageIO
#endif

/// Measures how big a downloaded image really is.
///
/// A site can state any size it likes and serve something else, so the stated size is a
/// ranking hint and this is the number that feeds confidence. A `.ico` holds several
/// resolutions in one file, so every frame is measured and the largest wins.
enum ImagePixelSize {
    /// The shortest side of the largest frame, or `nil` when the bytes cannot be measured.
    ///
    /// The shortest side rather than the longest, because a wide wordmark padded to 512 across
    /// and 64 down is 64 pixels of icon.
    static func shortestSide(of data: Data) -> Int? {
        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        var best: Int?
        for index in 0..<CGImageSourceGetCount(source) {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0 else { continue }
            best = max(best ?? 0, min(width, height))
        }
        return best
        #else
        return nil
        #endif
    }
}

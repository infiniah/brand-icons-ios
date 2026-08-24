#if canImport(SwiftUI)
import SwiftUI

/// A SwiftUI `Shape` that draws an SVG path, scaled to fit its rect and centred.
///
/// The path is parsed once per distinct path string and cached, because a list redrawing on
/// scroll would otherwise re-parse the same geometry on every frame.
public struct BrandVectorShape: Shape {
    private let pathData: String
    private let viewBox: CGRect

    public init(pathData: String, viewBox: CGRect) {
        self.pathData = pathData
        self.viewBox = viewBox
    }

    public func path(in rect: CGRect) -> Path {
        guard let parsed = ParsedPathCache.shared.path(for: pathData), !viewBox.isEmpty else {
            return Path()
        }

        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let width = viewBox.width * scale
        let height = viewBox.height * scale

        var transform = CGAffineTransform.identity
            .translatedBy(x: rect.midX - width / 2, y: rect.midY - height / 2)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -viewBox.minX, y: -viewBox.minY)

        guard let scaled = parsed.copy(using: &transform) else { return Path() }
        return Path(scaled)
    }
}

/// Caches parsed `CGPath` values keyed by their source string.
final class ParsedPathCache: @unchecked Sendable {
    static let shared = ParsedPathCache()

    private let lock = NSLock()
    private var storage: [String: CGPath] = [:]
    private var order: [String] = []
    private let limit = 512

    func path(for data: String) -> CGPath? {
        lock.lock()
        if let cached = storage[data] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let parsed = SVGPathParser.path(from: data) else { return nil }

        lock.lock()
        storage[data] = parsed
        order.append(data)
        if order.count > limit, let oldest = order.first {
            order.removeFirst()
            storage.removeValue(forKey: oldest)
        }
        lock.unlock()
        return parsed
    }
}
#endif

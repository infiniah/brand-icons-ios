import Foundation

/// An icon a site said it has, before anything has been downloaded.
///
/// Both the Web App Manifest and the document head describe icons the same way: a URL, an
/// optional stated size, and a hint about what the icon is for. Normalising them into one type
/// lets the provider rank every declaration a site makes against every other one.
struct DeclaredIcon: Hashable, Sendable {
    let url: URL

    /// The square size the site stated, `nil` when it stated none or stated only non-square ones.
    let declaredPixelSize: Int?

    /// What to rank it as when the site stated nothing.
    ///
    /// A bare `apple-touch-icon` is 180 by Apple's own convention, where a bare `rel="icon"` is
    /// usually the 32 pixel `.ico`. Ranking both at zero would let the small one win on a site
    /// that happens to declare a size for it and not for the other.
    let assumedPixelSize: Int

    /// Lower wins ties. Maskable icons carry safe-zone padding and scalable ones cannot be
    /// decoded into a bitmap here, so both lose to a plain raster of the same stated size.
    let preference: Int

    init(url: URL, declaredPixelSize: Int?, assumedPixelSize: Int = 0, preference: Int = 0) {
        self.url = url
        self.declaredPixelSize = declaredPixelSize
        self.assumedPixelSize = assumedPixelSize
        self.preference = preference
    }

    var rankedPixelSize: Int { declaredPixelSize ?? assumedPixelSize }

    /// Largest first, then by preference.
    static func betterFirst(_ lhs: DeclaredIcon, _ rhs: DeclaredIcon) -> Bool {
        if lhs.rankedPixelSize != rhs.rankedPixelSize { return lhs.rankedPixelSize > rhs.rankedPixelSize }
        return lhs.preference < rhs.preference
    }

    /// The largest square size in a `sizes` attribute or manifest field.
    ///
    /// The syntax is space separated `WxH` tokens, per both the manifest spec and the HTML
    /// `sizes` attribute. `any` means scalable and states no pixel count.
    static func largestSquare(in sizes: String) -> Int? {
        var best: Int?
        for token in sizes.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }) {
            let parts = token.lowercased().split(separator: "x")
            guard parts.count == 2,
                  let width = Int(parts[0]), let height = Int(parts[1]),
                  width == height, width > 0 else { continue }
            best = max(best ?? 0, width)
        }
        return best
    }

    static func declaresScalable(_ sizes: String) -> Bool {
        sizes.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .contains { $0.lowercased() == "any" }
    }
}

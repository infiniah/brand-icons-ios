#if canImport(SwiftUI)
import SwiftUI

/// Draws a resolved brand icon, falling back to a lettered tile when there is nothing to draw.
///
/// ```swift
/// BrandIconView(candidate: best, size: 40)
/// ```
///
/// A vector candidate is drawn in its own colours. A raster candidate is decoded as an image.
/// When `candidate` is nil the view draws the first letter of `fallbackText` on a tint derived
/// from that text, which keeps a list from developing holes while lookups are still in flight.
///
/// A mark too close in tone to the surface behind it gets a contrasting tile, so a near black
/// mark such as GitHub's stays visible in dark mode.
public struct BrandIconView: View {
    private let candidate: BrandIconCandidate?
    private let fallbackText: String
    private let size: CGFloat
    private let cornerRadius: CGFloat

    public init(
        candidate: BrandIconCandidate?,
        fallbackText: String = "",
        size: CGFloat = 40,
        cornerRadius: CGFloat? = nil
    ) {
        self.candidate = candidate
        self.fallbackText = fallbackText
        self.size = size
        self.cornerRadius = cornerRadius ?? size * 0.28
    }

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay(content)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityLabel(Text(accessibilityLabel))
    }

    @ViewBuilder
    private var content: some View {
        switch candidate?.shape {
        case let .vector(path, viewBox, tint):
            BrandVectorShape(pathData: path, viewBox: viewBox)
                .fill(tint.swiftUIColor)
                .padding(inset)
        case let .layeredVector(layers, viewBox):
            // Painted back to front in the order the artwork lists them, each in its own fill.
            ZStack {
                ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                    BrandVectorShape(pathData: layer.path, viewBox: viewBox)
                        .fill(
                            layer.fill?.swiftUIColor ?? Self.unsetFill,
                            style: FillStyle(eoFill: layer.isEvenOdd)
                        )
                }
            }
            .padding(inset)
        case let .raster(data):
            rasterImage(data)
        case .none:
            Text(initial)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
        }
    }

    @ViewBuilder
    private func rasterImage(_ data: Data) -> some View {
        #if canImport(UIKit)
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Text(initial).font(.system(size: size * 0.42, weight: .semibold))
        }
        #else
        Color.clear
        #endif
    }

    private var brandColor: BrandColor {
        if case let .vector(_, _, tint) = candidate?.shape { return tint }
        return BrandIconView.derivedTint(for: fallbackText)
    }

    /// Every colour the mark is actually painted in.
    private var markColors: [BrandColor] {
        switch candidate?.shape {
        case let .vector(_, _, tint): [tint]
        case let .layeredVector(layers, _): layers.compactMap(\.fill)
        default: []
        }
    }

    /// The tone the icon is sitting on, as far as the view can tell.
    private var surfaceLuminance: Double {
        colorScheme == .dark ? 0.08 : 0.96
    }

    /// True when nothing in the mark reads against the surface.
    private var needsTile: Bool {
        let colors = markColors
        guard !colors.isEmpty else { return false }
        return colors.allSatisfy { abs($0.relativeLuminance - surfaceLuminance) < 0.22 }
    }

    private var inset: CGFloat {
        needsTile ? size * 0.18 : 0
    }

    /// What SVG paints a path with no `fill` attribute.
    ///
    /// Taking the contrasting foreground instead makes a light layer and an unset one the same
    /// colour, which flattens a two tone mark into one blob.
    static let unsetFill = Color(red: 0.11, green: 0.11, blue: 0.12)

    private var background: Color {
        switch candidate?.shape {
        case .none:
            return brandColor.swiftUIColor
        case .raster:
            return .clear
        default:
            guard needsTile else { return .clear }
            // Light behind a dark mark, dark behind a light one.
            let dark = markColors.allSatisfy { $0.relativeLuminance < 0.5 }
            return dark ? Color(white: 0.95) : Color(white: 0.11)
        }
    }

    /// The monogram colour, against the derived tile a nil candidate gets.
    private var foreground: Color {
        brandColor.relativeLuminance >= 0.53 ? Color(white: 0.06) : .white
    }

    private var initial: String {
        String(fallbackText.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    private var accessibilityLabel: String {
        candidate?.title ?? fallbackText
    }

    /// A stable colour for a name, so an unresolved row still looks deliberate.
    static func derivedTint(for text: String) -> BrandColor {
        var hash: UInt64 = 5381
        for byte in text.lowercased().utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        let hue = Double(hash % 360) / 360
        return BrandColor.fromHSB(hue: hue, saturation: 0.52, brightness: 0.58)
    }
}

extension BrandColor {
    static func fromHSB(hue: Double, saturation: Double, brightness: Double) -> BrandColor {
        let sector = hue * 6
        let index = Int(sector) % 6
        let fraction = sector - Double(Int(sector))
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * fraction)
        let t = brightness * (1 - saturation * (1 - fraction))

        let rgb: (Double, Double, Double)
        switch index {
        case 0: rgb = (brightness, t, p)
        case 1: rgb = (q, brightness, p)
        case 2: rgb = (p, brightness, t)
        case 3: rgb = (p, q, brightness)
        case 4: rgb = (t, p, brightness)
        default: rgb = (brightness, p, q)
        }
        return BrandColor(
            red: UInt8(rgb.0 * 255),
            green: UInt8(rgb.1 * 255),
            blue: UInt8(rgb.2 * 255)
        )
    }
}
#endif

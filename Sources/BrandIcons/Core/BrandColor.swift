import Foundation

/// An sRGB colour, stored as eight bits per channel so it can cross module and process
/// boundaries without dragging in a UI framework.
public struct BrandColor: Hashable, Sendable, Codable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses `#RGB`, `#RRGGBB` or `#RRGGBBAA`, with or without the leading hash.
    public init?(hex: String) {
        var text = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        // `#fff` and `#ffff` are both shorthand, the second carrying alpha. Artwork writes white
        // both ways, and a parser that rejects either drops the light layer of a two tone mark.
        if text.count == 3 || text.count == 4 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6 || text.count == 8, let value = UInt32(text, radix: 16) else { return nil }
        if text.count == 6 {
            self.init(
                red: UInt8((value >> 16) & 0xFF),
                green: UInt8((value >> 8) & 0xFF),
                blue: UInt8(value & 0xFF)
            )
        } else {
            self.init(
                red: UInt8((value >> 24) & 0xFF),
                green: UInt8((value >> 16) & 0xFF),
                blue: UInt8((value >> 8) & 0xFF),
                alpha: UInt8(value & 0xFF)
            )
        }
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// Relative luminance per WCAG 2.1, used to choose a readable foreground.
    public var relativeLuminance: Double {
        func channel(_ raw: UInt8) -> Double {
            let value = Double(raw) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// Contrast ratio against another colour, 1 to 21.
    public func contrastRatio(against other: BrandColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    public static let white = BrandColor(red: 255, green: 255, blue: 255)
    public static let black = BrandColor(red: 0, green: 0, blue: 0)
}

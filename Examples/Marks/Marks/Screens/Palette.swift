import SwiftUI

enum Palette {
    static let canvasLight: UInt32 = 0xF4F4F2
    static let canvasDark: UInt32 = 0x0E0F11
    static let cardLight: UInt32 = 0xFFFFFF
    static let cardDark: UInt32 = 0x191B1E

    static let canvas = Color(light: canvasLight, dark: canvasDark)
    static let card = Color(light: cardLight, dark: cardDark)
    static let hairline = Color(light: 0xE6E5E1, dark: 0x2A2D31)

    /// How light a ground is, so `BrandIconView` can decide whether a mark reads against it.
    static func luminance(_ rgb: UInt32) -> Double {
        let red = Double((rgb >> 16) & 0xFF) / 255
        let green = Double((rgb >> 8) & 0xFF) / 255
        let blue = Double(rgb & 0xFF) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    static func canvasLuminance(_ scheme: ColorScheme) -> Double {
        luminance(scheme == .dark ? canvasDark : canvasLight)
    }

    static func cardLuminance(_ scheme: ColorScheme) -> Double {
        luminance(scheme == .dark ? cardDark : cardLight)
    }
    static let title = Color(light: 0x14161A, dark: 0xF4F4F2)
    static let secondary = Color(light: 0x6C7076, dark: 0x9AA0A6)
    static let tertiary = Color(light: 0x9CA1A7, dark: 0x6E747A)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        // UIKit resolves this from whichever thread is drawing, and the project compiles with
        // `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without `@Sendable` the closure is main
        // actor isolated and SwiftUI's async render pass traps on the isolation check.
        let lightColor = UIColor(rgb: light)
        let darkColor = UIColor(rgb: dark)
        self.init(uiColor: UIColor { @Sendable traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
        #else
        self.init(rgb: light)
        #endif
    }

    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

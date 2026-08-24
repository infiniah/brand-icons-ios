import SwiftUI

enum Palette {
    static let canvas = Color(light: 0xF4F4F2, dark: 0x0E0F11)
    static let card = Color(light: 0xFFFFFF, dark: 0x191B1E)
    static let hairline = Color(light: 0xE6E5E1, dark: 0x2A2D31)
    static let title = Color(light: 0x14161A, dark: 0xF4F4F2)
    static let secondary = Color(light: 0x6C7076, dark: 0x9AA0A6)
    static let tertiary = Color(light: 0x9CA1A7, dark: 0x6E747A)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
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

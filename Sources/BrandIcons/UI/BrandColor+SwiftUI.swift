#if canImport(SwiftUI)
import SwiftUI

public extension BrandColor {
    /// The colour as SwiftUI sees it.
    var swiftUIColor: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}
#endif

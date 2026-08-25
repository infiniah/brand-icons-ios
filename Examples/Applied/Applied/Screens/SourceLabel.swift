import BrandIcons

extension BrandIconSource {
    /// What to call this tier in front of a person.
    ///
    /// The raw values are API identifiers. `appStore` also needs qualifying, because Apple's is
    /// the store being asked on every platform.
    var label: String {
        switch self {
        case .bundled: "Bundled"
        case .appStore: "Apple App Store"
        case .favicon: "Site icon"
        }
    }
}

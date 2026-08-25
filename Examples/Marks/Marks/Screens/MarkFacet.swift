import BrandIcons

enum MarkFacet: String, CaseIterable, Identifiable {
    case all = "All"
    case color = "Colour"
    case monochrome = "One tint"
    case restricted = "Restricted"

    var id: String { rawValue }

    func contains(_ mark: BundledMark) -> Bool {
        switch self {
        case .all: true
        case .color: !mark.layers.isEmpty
        case .monochrome: mark.layers.isEmpty
        case .restricted: mark.license?.isRestrictive == true
        }
    }
}

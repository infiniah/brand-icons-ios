import Foundation

/// One filled path of a multi colour mark.
///
/// Simple Icons is monochrome by construction, so a mark from it is a single path and a single
/// tint. A brand whose identity is colour is not: Figma is five shapes in five colours, and
/// flattening it to one path produces a hollow outline that reads as a different logo. Those
/// marks arrive as an ordered list of these, painted back to front.
public struct VectorLayer: Hashable, Sendable {
    /// SVG path data, in the coordinate space of the shape's viewBox.
    public let path: String

    /// The layer's own fill. Nil means the artwork left it to the renderer, which paints the
    /// brand tint rather than guessing.
    public let fill: BrandColor?

    public init(path: String, fill: BrandColor?) {
        self.path = path
        self.fill = fill
    }
}

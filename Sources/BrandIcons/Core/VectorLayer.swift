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

    /// Whether the layer fills by the even odd rule rather than the non zero winding default.
    ///
    /// Not a detail: a mark that punches holes with `fill-rule="evenodd"` and is filled by
    /// winding instead comes out solid. Duolingo's eyes disappear.
    public let isEvenOdd: Bool

    public init(path: String, fill: BrandColor?, isEvenOdd: Bool = false) {
        self.path = path
        self.fill = fill
        self.isEvenOdd = isEvenOdd
    }
}

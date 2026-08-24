import Foundation

/// One letter of SVG path data, split into what it draws and whether its operands are
/// relative to the current point.
struct SVGPathCommand: Hashable {
    enum Kind: Hashable {
        case move
        case close
        case line
        case horizontalLine
        case verticalLine
        case cubic
        case smoothCubic
        case quadratic
        case smoothQuadratic
        case arc
    }

    let kind: Kind
    let isRelative: Bool

    init?(_ byte: UInt8) {
        let lowered = byte | 0x20
        switch lowered {
        case UInt8(ascii: "m"): kind = .move
        case UInt8(ascii: "z"): kind = .close
        case UInt8(ascii: "l"): kind = .line
        case UInt8(ascii: "h"): kind = .horizontalLine
        case UInt8(ascii: "v"): kind = .verticalLine
        case UInt8(ascii: "c"): kind = .cubic
        case UInt8(ascii: "s"): kind = .smoothCubic
        case UInt8(ascii: "q"): kind = .quadratic
        case UInt8(ascii: "t"): kind = .smoothQuadratic
        case UInt8(ascii: "a"): kind = .arc
        default: return nil
        }
        isRelative = lowered == byte
    }

    private init(kind: Kind, isRelative: Bool) {
        self.kind = kind
        self.isRelative = isRelative
    }

    /// What a bare run of extra operands means.
    ///
    /// The grammar lets a command letter be given once and its operands repeated, so
    /// `M0 0 1 1` is a move followed by a line. `Z` takes no operands, so it has no
    /// repeated form and trailing numbers after one are malformed.
    var repeated: SVGPathCommand? {
        switch kind {
        case .close: nil
        case .move: SVGPathCommand(kind: .line, isRelative: isRelative)
        default: self
        }
    }
}

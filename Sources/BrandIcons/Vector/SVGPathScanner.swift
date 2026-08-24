import CoreGraphics
import Foundation

/// Reads SVG path data one token at a time.
///
/// Path data is ASCII by grammar, so the text is held as bytes. That matters: an icon path
/// runs to several thousand characters and is re-read whenever a cache misses.
struct SVGPathScanner {
    private let bytes: [UInt8]
    private var index = 0

    init(_ text: String) {
        bytes = Array(text.utf8)
    }

    /// True once nothing but separators remains.
    var isAtEnd: Bool {
        var probe = index
        while probe < bytes.count, Self.isSeparator(bytes[probe]) { probe += 1 }
        return probe >= bytes.count
    }

    /// True when the next token starts a number, so a command can be repeated implicitly.
    var hasNumber: Bool {
        var probe = index
        while probe < bytes.count, Self.isSeparator(bytes[probe]) { probe += 1 }
        guard probe < bytes.count else { return false }
        return Self.isDigit(bytes[probe]) || Self.isSignOrPoint(bytes[probe])
    }

    /// The next command letter, or nil when the next token is not one.
    ///
    /// A letter that is not a path command is left in place rather than consumed, so the
    /// caller sees malformed data instead of silently skipping it.
    mutating func nextCommand() -> SVGPathCommand? {
        skipSeparators()
        guard index < bytes.count, let command = SVGPathCommand(bytes[index]) else { return nil }
        index += 1
        return command
    }

    mutating func nextNumber() -> CGFloat? {
        skipSeparators()
        guard index < bytes.count else { return nil }

        let start = index
        var sawDigit = false
        var sawPoint = false

        if Self.isSign(bytes[index]) { index += 1 }

        while index < bytes.count {
            let byte = bytes[index]
            if Self.isDigit(byte) {
                sawDigit = true
                index += 1
            } else if byte == Self.point, !sawPoint {
                sawPoint = true
                index += 1
            } else {
                break
            }
        }

        guard sawDigit else {
            index = start
            return nil
        }

        if index < bytes.count, bytes[index] == Self.lowerE || bytes[index] == Self.upperE {
            let beforeExponent = index
            index += 1
            if index < bytes.count, Self.isSign(bytes[index]) { index += 1 }
            var sawExponentDigit = false
            while index < bytes.count, Self.isDigit(bytes[index]) {
                sawExponentDigit = true
                index += 1
            }
            if !sawExponentDigit { index = beforeExponent }
        }

        let literal = String(decoding: bytes[start..<index], as: UTF8.self)
        guard let value = Double(literal), value.isFinite else {
            index = start
            return nil
        }
        return CGFloat(value)
    }

    /// An arc flag, which the grammar defines as the single character `0` or `1`.
    mutating func nextFlag() -> Bool? {
        skipSeparators()
        guard index < bytes.count else { return nil }
        let byte = bytes[index]
        guard byte == Self.zero || byte == Self.one else { return nil }
        index += 1
        return byte == Self.one
    }

    private mutating func skipSeparators() {
        while index < bytes.count, Self.isSeparator(bytes[index]) { index += 1 }
    }

    private static let point = UInt8(ascii: ".")
    private static let zero = UInt8(ascii: "0")
    private static let nine = UInt8(ascii: "9")
    private static let one = UInt8(ascii: "1")
    private static let lowerE = UInt8(ascii: "e")
    private static let upperE = UInt8(ascii: "E")

    private static let separators: Set<UInt8> = Set([0x20, 0x09, 0x0A, 0x0D, 0x0C, 0x0B])
        .union([UInt8(ascii: ",")])

    private static func isSeparator(_ byte: UInt8) -> Bool { separators.contains(byte) }
    private static func isDigit(_ byte: UInt8) -> Bool { byte >= zero && byte <= nine }
    private static func isSign(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+")
    }

    private static func isSignOrPoint(_ byte: UInt8) -> Bool { isSign(byte) || byte == point }
}

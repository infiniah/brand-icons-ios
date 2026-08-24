import Foundation

/// The licence Simple Icons records for one icon, when it records one.
///
/// Simple Icons as a project is released under CC0, but individual icons are not all CC0,
/// and the licence on any one of them can change between releases. A few marks in this
/// catalogue carry copyleft or attribution terms. Read NOTICE, and check this before
/// shipping a mark somewhere the terms matter.
public struct BundledMarkLicense: Hashable, Sendable {
    /// An SPDX identifier such as `CC0-1.0` or `MIT`, or `custom` when the brand sets its
    /// own terms, in which case ``url`` points at them.
    public let type: String

    /// Where the terms are published, for a `custom` licence.
    public let url: URL?

    public init(type: String, url: URL? = nil) {
        self.type = type
        self.url = url
    }

    /// True when the terms forbid commercial use.
    ///
    /// Shipping a mark under these in a paid app is a problem the package cannot solve for
    /// you, so it reports the fact rather than deciding.
    public var isNonCommercial: Bool { type.contains("-NC") }

    /// True when the terms forbid derivative works.
    ///
    /// This one is sharper than it looks. The package reparses every mark's path and rescales
    /// it to the size a caller asked for, and whether that constitutes a derivative is a
    /// question for a lawyer rather than for a library. `BrandIcons` flags it and gets out of
    /// the way.
    public var isNoDerivatives: Bool { type.contains("-ND") }

    /// True when the terms require derivative works to carry the same licence.
    public var isShareAlike: Bool { type.contains("-SA") }

    /// True when the terms need more from you than CC0 does.
    ///
    /// Attribution alone is not counted here. `CC-BY` asks for credit, which most projects can
    /// give; NonCommercial and NoDerivatives can make a mark unusable outright, which is a
    /// different kind of problem.
    public var isRestrictive: Bool { isNonCommercial || isNoDerivatives }
}

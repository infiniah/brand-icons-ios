import BrandIcons
import Foundation

/// What the app knows about one row's icon lookup.
struct IconResolution: Hashable {
    var result: BrandIconResult?
    var chosen: BrandIconCandidate?

    static let unresolved = IconResolution(result: nil, chosen: nil)

    var isAmbiguous: Bool {
        result?.isAmbiguous() ?? false
    }

    var alternatives: [BrandIconCandidate] {
        result?.candidates ?? []
    }

    /// The grey third line under the role.
    ///
    /// This is the one element on the screen with no reference behind it. It exists because
    /// the app is a demonstration of the library, so which tier answered and how sure it was
    /// is the interesting part rather than an implementation detail to hide.
    var caption: String? {
        guard let chosen else {
            return result == nil ? nil : "no match"
        }
        let percent = Int((chosen.confidence * 100).rounded())
        return "\(chosen.source.rawValue) · \(percent)%"
    }
}

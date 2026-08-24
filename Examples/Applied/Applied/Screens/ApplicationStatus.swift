import SwiftUI

enum ApplicationStatus: String, CaseIterable, Hashable {
    case applied = "Applied"
    case interview = "Interview"
    case offer = "Offer"
    case rejected = "Rejected"

    var tint: Color {
        switch self {
        case .applied: Color(red: 0.42, green: 0.45, blue: 0.50)
        case .interview: Color(red: 0.11, green: 0.40, blue: 0.87)
        case .offer: Color(red: 0.06, green: 0.50, blue: 0.31)
        case .rejected: Color(red: 0.70, green: 0.19, blue: 0.20)
        }
    }

    var wash: Color { tint.opacity(0.12) }
}

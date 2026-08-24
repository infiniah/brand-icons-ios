import Foundation

struct Application: Identifiable, Hashable {
    let id = UUID()
    var company: String
    var domain: String?
    var role: String
    var status: ApplicationStatus
    var appliedOn: Date

    static let sample: [Application] = {
        let calendar = Calendar.current
        let today = Date()
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: today) ?? today
        }

        return [
            Application(
                company: "Linear",
                domain: "linear.app",
                role: "Senior iOS Engineer",
                status: .interview,
                appliedOn: daysAgo(3)
            ),
            Application(
                company: "Figma",
                domain: "figma.com",
                role: "Platform Engineer, Design Systems",
                status: .applied,
                appliedOn: daysAgo(6)
            ),
            Application(
                company: "Stripe",
                domain: "stripe.com",
                role: "Mobile Infrastructure",
                status: .offer,
                appliedOn: daysAgo(21)
            ),
            Application(
                company: "NOTION LABS INC",
                domain: nil,
                role: "iOS Engineer",
                status: .applied,
                appliedOn: daysAgo(9)
            ),
            Application(
                company: "Apple",
                domain: nil,
                role: "SwiftUI Frameworks",
                status: .rejected,
                appliedOn: daysAgo(34)
            ),
            Application(
                company: "Duolingo",
                domain: "duolingo.com",
                role: "Senior Engineer, Learning",
                status: .interview,
                appliedOn: daysAgo(12)
            ),
            Application(
                company: "Monzo Bank Ltd",
                domain: "monzo.com",
                role: "iOS Engineer, Payments",
                status: .applied,
                appliedOn: daysAgo(2)
            ),
            Application(
                company: "Hypercorrect Labs",
                domain: nil,
                role: "Founding Engineer",
                status: .applied,
                appliedOn: daysAgo(1)
            )
        ]
    }()
}

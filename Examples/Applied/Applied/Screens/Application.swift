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
                company: "Figma",
                domain: "figma.com",
                role: "Senior Product Engineer",
                status: .interview,
                appliedOn: daysAgo(2)
            ),
            Application(
                company: "Duolingo",
                domain: "duolingo.com",
                role: "Android Engineer, Learning",
                status: .applied,
                appliedOn: daysAgo(5)
            ),
            Application(
                company: "Spotify",
                domain: "spotify.com",
                role: "Engineering Manager, Playback",
                status: .offer,
                appliedOn: daysAgo(8)
            ),
            Application(
                company: "Microsoft",
                domain: "microsoft.com",
                role: "Principal SWE, Developer Division",
                status: .applied,
                appliedOn: daysAgo(9)
            ),
            Application(
                company: "Notion",
                domain: "notion.so",
                role: "Product Engineer, Databases",
                status: .rejected,
                appliedOn: daysAgo(14)
            ),
            Application(
                company: "GitHub",
                domain: "github.com",
                role: "Staff Engineer, Actions",
                status: .interview,
                appliedOn: daysAgo(21)
            )
        ]
    }()
}

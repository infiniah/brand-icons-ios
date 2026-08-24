import SwiftUI

struct StatusPill: View {
    let status: ApplicationStatus

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(status.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.wash, in: Capsule())
    }
}

#Preview("Status pills") {
    HStack(spacing: 8) {
        ForEach(ApplicationStatus.allCases, id: \.self, content: StatusPill.init)
    }
    .padding()
}

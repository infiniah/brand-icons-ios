import BrandIcons
import SwiftUI

struct ApplicationRow: View {
    let application: Application
    let resolution: IconResolution
    let onTapIcon: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTapIcon) {
                BrandIconView(
                    candidate: resolution.chosen,
                    fallbackText: application.company,
                    size: 40
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Change the icon for \(application.company)"))

            VStack(alignment: .leading, spacing: 2) {
                Text(application.company)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.title)
                    .lineLimit(1)

                Text(application.role)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)

                if let caption = resolution.caption {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                StatusPill(status: application.status)
                Text(application.appliedOn, format: .dateTime.day().month(.abbreviated))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview("Row") {
    VStack(spacing: 0) {
        ApplicationRow(
            application: Application.sample[0],
            resolution: .unresolved,
            onTapIcon: {}
        )
    }
    .background(Palette.card)
}

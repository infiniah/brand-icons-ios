import SwiftUI

/// A text field whose label sits above the box and hint below it, as in Remote Global HR's
/// invoice form, so neither is lost once there is text in the field.
struct LabelledField<Accessory: View>: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var hint: String?
    var systemImage: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .padding(.leading, 2)

            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.tertiary)
                }
                TextField(placeholder, text: $text)
                accessory()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )

            if let hint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.tertiary)
                    .padding(.leading, 2)
            }
        }
    }
}

extension LabelledField where Accessory == EmptyView {
    init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        hint: String? = nil,
        systemImage: String? = nil
    ) {
        self.init(
            label: label,
            placeholder: placeholder,
            text: text,
            hint: hint,
            systemImage: systemImage
        ) { EmptyView() }
    }
}

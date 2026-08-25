import BrandIcons
import SwiftUI

struct MarkDetailSheet: View {
    let mark: BundledMark
    let dismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var candidate: BrandIconCandidate {
        BrandIconCandidate(
            slug: mark.slug,
            title: mark.title,
            confidence: 1,
            source: .bundled,
            shape: BundledIconProvider.shape(for: mark)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.card)
                    .frame(height: 200)
                    .overlay(
                        BrandIconView(
                            candidate: candidate,
                            size: 120,
                            surface: Palette.cardLuminance(colorScheme)
                        )
                    )

                Text(facts)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)

                sizes
                grounds
                technical
            }
            .padding(20)
        }
        .background(Palette.canvas)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mark.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.title)
                Text(mark.slug)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.tertiary)
            }
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 30, height: 30)
                    .background(Palette.card, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var facts: String {
        var parts = [mark.layers.isEmpty ? "Monochrome" : "\(mark.layers.count) colour layers"]
        parts.append(mark.tint.hexString)
        parts.append(mark.license?.type ?? "no licence on file")
        if mark.license?.isRestrictive == true { parts.append("restrictive") }
        return parts.joined(separator: " · ")
    }

    private var sizes: some View {
        Panel(label: "Every size from one path") {
            HStack(alignment: .bottom, spacing: 22) {
                ForEach([20.0, 28.0, 40.0, 56.0], id: \.self) { size in
                    VStack(spacing: 8) {
                        BrandIconView(
                            candidate: candidate,
                            size: size,
                            surface: Palette.cardLuminance(colorScheme)
                        )
                        Text("\(Int(size))")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// A mark that reads on one ground can vanish on the other, so the view puts a contrasting
    /// tile behind one that would. Both grounds are shown because only one of them is the
    /// reader's.
    private var grounds: some View {
        Panel(label: "On either ground") {
            HStack(spacing: 12) {
                ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                    BrandIconView(
                        candidate: candidate,
                        size: 44,
                        surface: Palette.luminance(scheme == .light ? 0xF4F4F2 : 0x141414)
                    )
                        .environment(\.colorScheme, scheme)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            scheme == .light ? Color(white: 0.96) : Color(white: 0.08),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
            }
        }
    }

    private var technical: some View {
        Panel(label: "Geometry", badge: mark.layers.isEmpty ? "VECTOR" : "LAYERED") {
            VStack(spacing: 8) {
                row("View box", "\(Int(box.width)) × \(Int(box.height))")
                row("Path data", "\(bytes.formatted()) bytes")
                row("Layers", mark.layers.isEmpty ? "none" : "\(mark.layers.count)")
            }
        }
    }

    private var box: CGRect { mark.colorViewBox ?? mark.viewBox }

    private var bytes: Int {
        mark.layers.isEmpty
            ? mark.pathData.utf8.count
            : mark.layers.reduce(0) { $0 + $1.path.utf8.count }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Palette.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Palette.title)
        }
    }
}

private struct Panel<Content: View>: View {
    let label: String
    var badge: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview("Colour") {
    MarkDetailSheet(mark: BundledCatalog.mark(slug: "figma")!, dismiss: {})
}

#Preview("Monochrome dark") {
    MarkDetailSheet(mark: BundledCatalog.mark(slug: "swift")!, dismiss: {})
        .preferredColorScheme(.dark)
}

import BrandIcons
import SwiftUI

/// Shows what every tier returned for one query, ranked, with the time each took.
///
/// Composition follows Quo's "Your connection": a grouped card whose rows carry a name with
/// an explanatory grey subtitle on the left, and a verdict above a measured value on the
/// right. Ranking with a marked winner follows Flighty's sorted disruption table.
///
/// The point of the screen is that the two axes disagree. The bundled catalogue is almost
/// always fastest and often most confident, but it only knows what was compiled into it, so
/// a name it misses is exactly where a slower tier earns its place.
struct TierComparison: View {
    let probes: [ProviderProbe]
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tiers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                if isRunning {
                    ProgressView().controlSize(.mini)
                } else if let fastest {
                    Text("fastest \(fastest.source.label)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.tertiary)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(probes.enumerated()), id: \.element.id) { index, probe in
                    row(probe, isWinner: index == 0 && probe.topConfidence > 0)
                    if index < probes.count - 1 {
                        Divider().foregroundStyle(Palette.hairline).padding(.leading, 16)
                    }
                }
            }
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 16)
    }

    private var fastest: ProviderProbe? {
        probes.filter { !$0.candidates.isEmpty }.min { $0.duration < $1.duration }
    }

    private func row(_ probe: ProviderProbe, isWinner: Bool) -> some View {
        HStack(spacing: 12) {
            BrandIconView(
                candidate: probe.candidates.first,
                fallbackText: probe.source.label,
                size: 34
            )
            .opacity(probe.candidates.isEmpty ? 0.25 : 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(probe.source.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.title)
                    if isWinner {
                        Text("BEST")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Palette.card)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Palette.title, in: Capsule())
                    }
                }
                Text(subtitle(for: probe))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(verdict(for: probe))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(verdictTint(for: probe))
                Text("\(probe.milliseconds) ms")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func subtitle(for probe: ProviderProbe) -> String {
        if let failure = probe.failure { return description(of: failure) }
        guard let best = probe.candidates.first else { return "no match" }
        let extra = probe.candidates.count - 1
        return extra > 0 ? "\(best.title), \(extra) more" : best.title
    }

    private func verdict(for probe: ProviderProbe) -> String {
        guard probe.failure == nil else { return "failed" }
        guard !probe.candidates.isEmpty else { return "none" }
        return "\(Int((probe.topConfidence * 100).rounded()))%"
    }

    private func verdictTint(for probe: ProviderProbe) -> Color {
        guard probe.failure == nil else { return ApplicationStatus.rejected.tint }
        switch probe.topConfidence {
        case 0.85...: return ApplicationStatus.offer.tint
        case 0.5..<0.85: return ApplicationStatus.interview.tint
        case 0.01..<0.5: return Palette.secondary
        default: return Palette.tertiary
        }
    }

    private func description(of failure: BrandIconError) -> String {
        switch failure {
        case .notFound: "no match"
        case .unreadableResponse: "unreadable response"
        case let .rateLimited(retryAfter):
            retryAfter.map { "rate limited, retry in \(Int($0))s" } ?? "rate limited"
        case let .providerDisabled(source): "\(source.label) is off"
        case let .transport(message): message
        }
    }
}

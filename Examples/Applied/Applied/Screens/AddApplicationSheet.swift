import BrandIcons
import SwiftUI

/// Adds an application, resolving the company's mark live as you type.
///
/// Composition follows TheFork's "Add a restaurant": a centred title with a circular close, a
/// search field pinned at the top, then results as rows with a leading square mark and a grey
/// secondary line. The trailing plus is replaced by the match percentage, because picking the
/// right brand is the decision here rather than adding an arbitrary row.
///
/// This screen is the honest test of the library. Type anything, including a company nobody
/// bundled, and watch which tier answers and how sure it is.
struct AddApplicationSheet: View {
    let onAdd: (Application, BrandIconCandidate?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var company = ""
    @State private var domain = ""
    @State private var role = ""
    @State private var status = ApplicationStatus.applied
    @State private var candidates: [BrandIconCandidate] = []
    @State private var chosen: BrandIconCandidate?

    /// Stops the exhaustive pass from overriding a candidate the user tapped.
    @State private var pickedManually = false
    @State private var isResolving = false
    @State private var searchTask: Task<Void, Never>?
    @State private var includesAppStore = false
    @State private var probes: [ProviderProbe] = []

    /// Bundled marks only. Answers instantly, so the list never sits empty while the network
    /// providers are still going.
    private let offlineResolver = BrandIconResolver(configuration: .offline)

    /// Every tier, every time.
    ///
    /// The default resolver stops as soon as the bundled catalogue answers confidently, so the
    /// network providers would never run for a name it already knows. This screen exists to
    /// compare them, so it asks all of them, which costs seconds rather than milliseconds.
    private func exhaustiveResolver() -> BrandIconResolver {
        var configuration = ResolverConfiguration.exhaustive
        configuration.allowsAppStore = includesAppStore
        return BrandIconResolver(configuration: configuration)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    field
                    domainField
                    if !probes.isEmpty || isResolving {
                        TierComparison(probes: probes, isRunning: isResolving)
                            .padding(.top, 16)
                    }
                    results
                    details
                }
            }
            .background(Palette.canvas)
            .navigationTitle("Add an application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", action: add)
                        .fontWeight(.semibold)
                        .disabled(company.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.tertiary)
            TextField("Company", text: $company)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: company) { _, value in resolve(value) }
            if isResolving {
                ProgressView().controlSize(.small)
            } else if !company.isEmpty {
                Button {
                    company = ""
                    candidates = []
                    chosen = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// Supplying a domain is what exercises the network tiers.
    ///
    /// catalogue has never heard of resolves through them and nowhere else. Leaving this
    /// empty is also a real case: the resolver falls back to guessing the host from the name.
    private var domainField: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .foregroundStyle(Palette.tertiary)
            TextField("Domain, optional. monzo.com", text: $domain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .onChange(of: domain) { _, _ in resolve(company) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var results: some View {
        if !candidates.isEmpty {
            VStack(spacing: 0) {
                ForEach(candidates) { candidate in
                    Button {
                        chosen = candidate
                        pickedManually = true
                    } label: {
                        candidateRow(candidate)
                    }
                    .buttonStyle(.plain)
                    Divider().foregroundStyle(Palette.hairline).padding(.leading, 72)
                }
            }
            .padding(.top, 14)
        } else if !company.isEmpty, !isResolving {
            Text("Nothing matched. It will use a lettered tile.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
        }
    }

    private func candidateRow(_ candidate: BrandIconCandidate) -> some View {
        HStack(spacing: 14) {
            BrandIconView(candidate: candidate, fallbackText: candidate.title, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.title)
                Text(candidate.source.rawValue)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondary)
            }

            Spacer(minLength: 8)

            Text("\(Int((candidate.confidence * 100).rounded()))%")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(candidate == chosen ? Palette.title : Palette.tertiary)

            if candidate == chosen {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.title)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Role", text: $role)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )

            Toggle("Also ask the App Store", isOn: $includesAppStore)
                .font(.system(size: 14))
                .onChange(of: includesAppStore) { _, _ in resolve(company) }

            Text("Apple limits that endpoint to roughly twenty requests a minute and its terms describe the artwork as promotional material for store content. It is off by default.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.tertiary)

            Picker("Status", selection: $status) {
                ForEach(ApplicationStatus.allCases, id: \.self) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 32)
    }

    /// Debounced, and resolved in two passes.
    ///
    /// The bundled pass is synchronous in practice and shows something immediately. The
    /// exhaustive pass then asks every network provider, which takes seconds, and replaces the
    /// list when it arrives. Without the first pass the screen looks like it found nothing for
    /// as long as the slowest provider takes to time out.
    private func resolve(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let host = domain.trimmingCharacters(in: .whitespaces)

        guard trimmed.count >= 2 else {
            candidates = []
            probes = []
            chosen = nil
            pickedManually = false
            isResolving = false
            return
        }

        let query = BrandQuery(name: trimmed, domain: host.isEmpty ? nil : host)

        searchTask = Task {
            defer { isResolving = false }
            isResolving = true

            let offlineResult = await offlineResolver.resolve(query)
            let bundled = await withShapes(offlineResult.candidates, using: offlineResolver)
            guard !Task.isCancelled else { return }
            candidates = bundled
            if !pickedManually { chosen = bundled.first }

            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            let resolver = exhaustiveResolver()
            let measured = await resolver.probe(query)
            guard !Task.isCancelled else { return }

            var withArt: [ProviderProbe] = []
            for probe in measured {
                let shaped = await withShapes(probe.candidates, using: resolver)
                withArt.append(
                    ProviderProbe(
                        source: probe.source,
                        duration: probe.duration,
                        candidates: shaped,
                        failure: probe.failure
                    )
                )
            }
            guard !Task.isCancelled else { return }

            probes = withArt

            // Ranked through `BrandIconResult` rather than by confidence alone, so the App Store
            // preference applies here too. Sorting on confidence would put Simple Icons' white
            // outline of Figma above the real coloured app icon, since both are certainly Figma.
            let ranked = BrandIconResult(
                query: trimmed,
                candidates: withArt.flatMap(\.candidates),
                preferring: resolver.configuration.effectivePreferredSources
            )
            candidates = Array(ranked.candidates.prefix(8))
            if !pickedManually { chosen = candidates.first }
        }
    }

    private func withShapes(
        _ candidates: [BrandIconCandidate],
        using resolver: BrandIconResolver
    ) async -> [BrandIconCandidate] {
        var output: [BrandIconCandidate] = []
        for candidate in candidates.prefix(8) {
            if candidate.shape == nil, let shape = try? await resolver.shape(for: candidate) {
                output.append(candidate.withShape(shape))
            } else {
                output.append(candidate)
            }
        }
        return output
    }

    private func add() {
        let name = company.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let host = domain.trimmingCharacters(in: .whitespaces)
        let application = Application(
            company: name,
            domain: host.isEmpty ? nil : host,
            role: role.isEmpty ? "Role not set" : role,
            status: status,
            appliedOn: Date()
        )
        onAdd(application, chosen)
        dismiss()
    }
}

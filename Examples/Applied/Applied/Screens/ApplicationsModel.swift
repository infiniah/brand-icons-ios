import BrandIcons
import Observation
import SwiftUI

@MainActor
@Observable
final class ApplicationsModel {
    private(set) var applications: [Application] = Application.sample
    private(set) var resolutions: [UUID: IconResolution] = [:]

    private let resolver = BrandIconResolver()

    func resolution(for application: Application) -> IconResolution {
        resolutions[application.id] ?? .unresolved
    }

    /// Resolves every row, then fetches the payload for whichever candidate won.
    ///
    /// Candidates arrive without a drawable shape so a lookup does not pay to download an icon
    /// the caller may discard. The winner is fetched here; the rest are fetched only if a person
    /// opens the chooser.
    func resolveAll() async {
        await withTaskGroup(of: (UUID, IconResolution).self) { group in
            for application in applications {
                group.addTask { [resolver] in
                    let query = BrandQuery(name: application.company, domain: application.domain)
                    let result = await resolver.resolve(query)
                    var chosen = result.best(minimum: 0.55)
                    if let candidate = chosen, candidate.shape == nil,
                       let shape = try? await resolver.shape(for: candidate) {
                        chosen = candidate.withShape(shape)
                    }
                    return (application.id, IconResolution(result: result, chosen: chosen))
                }
            }
            for await (id, resolution) in group {
                resolutions[id] = resolution
            }
        }
    }

    func add(_ application: Application, icon: BrandIconCandidate?) {
        applications.insert(application, at: 0)
        resolutions[application.id] = IconResolution(result: nil, chosen: icon)
        guard icon == nil else { return }
        Task { await resolveOne(application) }
    }

    private func resolveOne(_ application: Application) async {
        let query = BrandQuery(name: application.company, domain: application.domain)
        let result = await resolver.resolve(query)
        var chosen = result.best(minimum: 0.55)
        if let candidate = chosen, candidate.shape == nil,
           let shape = try? await resolver.shape(for: candidate) {
            chosen = candidate.withShape(shape)
        }
        resolutions[application.id] = IconResolution(result: result, chosen: chosen)
    }

    func choose(_ candidate: BrandIconCandidate?, for application: Application) {
        guard var current = resolutions[application.id] else { return }
        guard let candidate else {
            current.chosen = nil
            resolutions[application.id] = current
            return
        }
        current.chosen = candidate
        resolutions[application.id] = current

        guard candidate.shape == nil else { return }
        Task { [resolver] in
            guard let shape = try? await resolver.shape(for: candidate) else { return }
            var updated = resolutions[application.id]
            updated?.chosen = candidate.withShape(shape)
            resolutions[application.id] = updated
        }
    }
}

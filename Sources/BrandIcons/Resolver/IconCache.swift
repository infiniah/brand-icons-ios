import Foundation

/// Holds fetched icon payloads in memory, keyed by ``BrandIconCandidate/id``.
///
/// Bounded by bytes rather than by count, because the two payload kinds differ by orders of
/// magnitude: a vector path is a few hundred bytes and a 512 pixel PNG is tens of kilobytes.
/// Counting entries would either starve one or let the other run away. When the budget is
/// exceeded the least recently used entries go first.
public actor IconCache {
    public static let defaultByteBudget = 8 * 1024 * 1024

    /// The ceiling this cache keeps itself under.
    public let byteBudget: Int

    /// Bytes currently held.
    public private(set) var byteCount = 0

    private struct Entry {
        let shape: BrandIconShape
        let cost: Int
        var lastUsed: UInt64
    }

    private var entries: [String: Entry] = [:]
    private var accessCounter: UInt64 = 0

    public init(byteBudget: Int = IconCache.defaultByteBudget) {
        self.byteBudget = max(0, byteBudget)
    }

    /// The cached payload, marking it as recently used.
    public func shape(for id: String) -> BrandIconShape? {
        guard var entry = entries[id] else { return nil }
        accessCounter += 1
        entry.lastUsed = accessCounter
        entries[id] = entry
        return entry.shape
    }

    /// Stores a payload, evicting older ones if it no longer fits.
    ///
    /// A payload larger than the whole budget is dropped rather than stored, since keeping it
    /// would mean evicting everything else to hold one item.
    public func insert(_ shape: BrandIconShape, for id: String) {
        let cost = Self.cost(of: shape)
        guard cost <= byteBudget else {
            remove(id)
            return
        }

        remove(id)
        accessCounter += 1
        entries[id] = Entry(shape: shape, cost: cost, lastUsed: accessCounter)
        byteCount += cost
        evictIfNeeded()
    }

    public func remove(_ id: String) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        byteCount -= entry.cost
    }

    public func removeAll() {
        entries.removeAll()
        byteCount = 0
    }

    /// How many payloads are held.
    public func count() -> Int {
        entries.count
    }

    private func evictIfNeeded() {
        guard byteCount > byteBudget else { return }
        for id in entries.sorted(by: { $0.value.lastUsed < $1.value.lastUsed }).map(\.key) {
            remove(id)
            if byteCount <= byteBudget { return }
        }
    }

    static func cost(of shape: BrandIconShape) -> Int {
        switch shape {
        case let .raster(data):
            return data.count
        case let .vector(path, _, _):
            return path.utf8.count + 64
        }
    }
}

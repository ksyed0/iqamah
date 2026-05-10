import Foundation

// MARK: - Cache key

/// Uniquely identifies a computed grid: synodic month + criterion name.
/// Both d29 and d30 grids are cached together per key (see `CachedGridPair`).
struct HilalCacheKey: Hashable {
    let newMoonJD: Double
    let criterionName: String

    init(newMoonJD: Double, criterion: any VisibilityCriterion) {
        // Round to 4 decimal places (~8 seconds) — avoids floating-point key collisions
        self.newMoonJD = (newMoonJD * 10000).rounded() / 10000
        criterionName = criterion.name
    }
}

// MARK: - Cached grid pair

/// Both evenings computed together; invalidation removes both at once.
struct CachedGridPair {
    let d29: ContiguousArray<Int8>
    let d30: ContiguousArray<Int8>
}

// MARK: - LRU cache (max 6 entries, in-memory only)

/// Thread-safe LRU cache for HilalCalculator grid results.
/// Max 6 entries (~16,200 bytes each — negligible memory).
final class HilalLRUCache: @unchecked Sendable {
    private let lock = NSLock()
    private let capacity: Int
    private var store: [HilalCacheKey: CachedGridPair] = [:]
    private var order: [HilalCacheKey] = [] // front = most recently used

    init(capacity: Int = 6) {
        self.capacity = capacity
    }

    func get(key: HilalCacheKey) -> CachedGridPair? {
        lock.lock(); defer { lock.unlock() }
        guard let value = store[key] else { return nil }
        // Move to front (most recently used)
        order.removeAll { $0 == key }
        order.insert(key, at: 0)
        return value
    }

    func set(key: HilalCacheKey, value: CachedGridPair) {
        lock.lock(); defer { lock.unlock() }
        if store[key] != nil {
            order.removeAll { $0 == key }
        } else if store.count >= capacity, let lru = order.last {
            store.removeValue(forKey: lru)
            order.removeLast()
        }
        store[key] = value
        order.insert(key, at: 0)
    }

    /// For testing: returns current entry count.
    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return store.count
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        store.removeAll()
        order.removeAll()
    }
}

import Foundation

/// A thread-safe, lock-guarded concurrent map providing synchronized operations across concurrent tasks and actors.
///
/// Eliminates boilerplate locking code when maintaining shared registries, caching buffers, and lookup tables
/// that require synchronous nonisolated fast-path queries.
public final class ConcurrentMap<Key: Hashable, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Key: Value] = [:]

    public init() {}

    /// Accesses or modifies the value for the given key in a thread-safe manner.
    public subscript(key: Key) -> Value? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storage[key] = newValue
        }
    }

    /// Retrieves the value associated with `key`.
    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    /// Sets or updates the value associated with `key`.
    public func set(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    /// Removes and returns the value for `key`, if present.
    @discardableResult
    public func remove(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage.removeValue(forKey: key)
    }

    /// Checks whether `key` exists in the map.
    public func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] != nil
    }

    /// Returns a snapshot array of all values currently stored in the map.
    public var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.values)
    }

    /// Returns a snapshot array of all keys currently stored in the map.
    public var keys: [Key] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.keys)
    }

    /// Returns a snapshot dictionary copy of all key-value pairs currently stored.
    public var dictionary: [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    /// Total number of key-value pairs currently stored.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    /// Whether the map contains zero key-value pairs.
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.isEmpty
    }

    /// Purges all key-value pairs from the map.
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}

/// A thread-safe, lock-guarded concurrent set providing synchronized membership operations.
public final class ConcurrentSet<Element: Hashable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Set<Element> = []

    public init() {}

    /// Inserts an element into the set.
    public func insert(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        storage.insert(element)
    }

    /// Removes an element from the set.
    @discardableResult
    public func remove(_ element: Element) -> Element? {
        lock.lock()
        defer { lock.unlock() }
        return storage.remove(element)
    }

    /// Checks whether the set contains `element`.
    public func contains(_ element: Element) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.contains(element)
    }

    /// Total number of unique elements currently stored.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    /// Whether the set contains zero elements.
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.isEmpty
    }

    /// Purges all elements from the set.
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }

    /// Returns a snapshot array of all elements currently stored.
    public var elements: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage)
    }
}

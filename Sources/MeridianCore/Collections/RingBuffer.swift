import Foundation

/// A high-performance, fixed-capacity circular ring buffer with power-of-two bitmask indexing.
///
/// Unlike standard dynamic arrays where `removeFirst()` forces $O(N)$ contiguous element shifting in memory,
/// ``RingBuffer`` advances an internal head pointer in strictly **$O(1)$ time with zero memory copying**.
///
/// Capacity is automatically rounded up to the nearest power of two, replacing expensive integer division/modulo
/// instructions with a single bitwise AND operation (`index & mask`).
///
/// Conforms to `RandomAccessCollection`, allowing constant-time subscripting, iteration, and functional mapping.
public struct RingBuffer<Element: Sendable>: Sendable, RandomAccessCollection, MutableCollection {
    public typealias Index = Int

    /// The user-configured maximum capacity before eviction occurs.
    public let maxCapacity: Int

    /// The allocated buffer capacity (always a power of two).
    public let capacity: Int

    /// Bitmask for fast circular indexing (`capacity - 1`).
    private let mask: Int

    /// Flat contiguous backing array of optional elements.
    private var storage: [Element?]

    /// Index of the oldest element (read pointer).
    private var head: Int = 0

    /// Total number of elements currently stored.
    public private(set) var count: Int = 0

    /// Initializes a circular ring buffer with the specified maximum capacity.
    ///
    /// - Parameter capacity: The maximum number of elements the buffer holds before oldest elements are evicted.
    public init(capacity: Int) {
        precondition(capacity >= 1, "RingBuffer capacity must be at least 1")
        self.maxCapacity = capacity

        // Round up to nearest power of two
        var p = 1
        while p < capacity {
            p <<= 1
        }
        self.capacity = p
        self.mask = p - 1
        self.storage = [Element?](repeating: nil, count: p)
    }

    // MARK: - RandomAccessCollection Conformance

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return count
    }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    public func index(before i: Int) -> Int {
        return i - 1
    }

    /// Accesses the element at the specified zero-based logical index relative to the head.
    public subscript(position: Int) -> Element {
        get {
            precondition(position >= 0 && position < count, "RingBuffer index out of bounds")
            let slot = (head + position) & mask
            return storage[slot]!
        }
        set {
            precondition(position >= 0 && position < count, "RingBuffer index out of bounds")
            let slot = (head + position) & mask
            storage[slot] = newValue
        }
    }

    // MARK: - Ingestion & Eviction

    /// Appends a new element to the tail of the buffer.
    ///
    /// If the buffer is already at `maxCapacity`, the oldest element at the head is evicted and returned in $O(1)$ time.
    ///
    /// - Parameter element: The element to append.
    /// - Returns: The evicted oldest element if the buffer was at capacity; otherwise `nil`.
    @discardableResult
    public mutating func append(_ element: Element) -> Element? {
        if count >= maxCapacity {
            let evicted = storage[head]
            let writeSlot = (head + count) & mask
            storage[head] = nil
            storage[writeSlot] = element
            head = (head + 1) & mask
            return evicted
        } else {
            let writeSlot = (head + count) & mask
            storage[writeSlot] = element
            count += 1
            return nil
        }
    }

    /// Removes and returns the oldest element from the front of the buffer in strictly $O(1)$ time.
    ///
    /// - Returns: The evicted element, or `nil` if the buffer is empty.
    @discardableResult
    public mutating func popFirst() -> Element? {
        guard count > 0 else { return nil }
        let element = storage[head]
        storage[head] = nil
        head = (head + 1) & mask
        count -= 1
        return element
    }

    /// The oldest element in the buffer, or `nil` if empty.
    public var first: Element? {
        guard count > 0 else { return nil }
        return storage[head]
    }

    /// The newest element in the buffer, or `nil` if empty.
    public var last: Element? {
        guard count > 0 else { return nil }
        let tailSlot = (head + count - 1) & mask
        return storage[tailSlot]
    }

    /// Whether the buffer has reached its maximum capacity.
    public var isFull: Bool {
        return count >= maxCapacity
    }

    /// Clears and purges all elements from the buffer.
    public mutating func removeAll() {
        storage = [Element?](repeating: nil, count: capacity)
        head = 0
        count = 0
    }

    /// Returns a standard contiguous array of all elements currently in the buffer, ordered from oldest to newest.
    public var elements: [Element] {
        return Array(self)
    }
}

extension RingBuffer: Equatable where Element: Equatable {
    public static func == (lhs: RingBuffer<Element>, rhs: RingBuffer<Element>) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return lhs.elements == rhs.elements
    }
}

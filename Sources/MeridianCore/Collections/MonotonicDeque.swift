import Foundation

/// Order policy determining whether a ``MonotonicDeque`` tracks running minimums or maximums.
public enum MonotonicOrder: Sendable, Equatable {
    /// Values are maintained in monotonically increasing order: `peek()` yields the running minimum.
    case increasing
    /// Values are maintained in monotonically decreasing order: `peek()` yields the running maximum.
    case decreasing
}

/// A generic, tag-indexed monotonic double-ended queue (deque) providing amortized $O(1)$ running extremum queries.
///
/// Under normal sliding-window FIFO operations, elements that are dominated by newer arrivals are greedily pruned
/// from the tail, allowing running minimums or maximums to be inspected in strictly $O(1)$ time from the front.
/// If elements are retracted or evicted out of chronological sequence, an internal chronological buffer enables
/// seamless fallback reconstruction in $O(N)$ time, guaranteeing 100% mathematical precision.
public struct MonotonicDeque<Element: Comparable & Sendable, Tag: Comparable & Sendable>: Sendable, Equatable {
    /// An individual element paired with a sequence or timestamp tag.
    public struct Entry: Sendable, Equatable {
        public let element: Element
        public let tag: Tag

        public init(element: Element, tag: Tag) {
            self.element = element
            self.tag = tag
        }
    }

    /// The ordering policy governing this deque (increasing for minimum, decreasing for maximum).
    public let order: MonotonicOrder

    /// Active monotonic queue of non-dominated candidates.
    private var deque: [Entry] = []

    /// Complete chronological buffer of active entries used for out-of-order fallback reconstruction.
    private var buffer: [Entry] = []

    /// Initializes a monotonic deque with the specified ordering policy.
    ///
    /// - Parameter order: `.increasing` for minimum tracking, `.decreasing` for maximum tracking.
    public init(order: MonotonicOrder) {
        self.order = order
    }

    /// Total number of active entries currently tracked.
    public var count: Int {
        return buffer.count
    }

    /// Number of surviving candidate entries in the monotonic deque.
    public var dequeCount: Int {
        return deque.count
    }

    /// Whether the deque currently contains zero elements.
    public var isEmpty: Bool {
        return buffer.isEmpty
    }

    /// Returns the current running extremum entry (minimum for `.increasing`, maximum for `.decreasing`) in $O(1)$ time.
    public func peek() -> Entry? {
        return deque.first
    }

    /// Returns the raw extremum element payload in $O(1)$ time, or `nil` if empty.
    public var extremum: Element? {
        return deque.first?.element
    }

    /// Pushes a new observation into the deque with an associated sequence or timestamp tag.
    ///
    /// - Parameters:
    ///   - element: The comparable element value.
    ///   - tag: A unique chronological sequence number or timestamp tag.
    public mutating func push(element: Element, tag: Tag) {
        let entry = Entry(element: element, tag: tag)
        buffer.append(entry)

        switch order {
        case .increasing:
            // For MIN: elements >= new element are dominated and pruned from tail
            while let last = deque.last, last.element >= element {
                deque.removeLast()
            }
        case .decreasing:
            // For MAX: elements <= new element are dominated and pruned from tail
            while let last = deque.last, last.element <= element {
                deque.removeLast()
            }
        }
        deque.append(entry)
    }

    /// Evicts an element matching the given tag from the deque.
    ///
    /// - Parameter tag: The tag identifying the entry to remove.
    /// - Returns: `true` if an entry with the tag was found and removed; `false` otherwise.
    @discardableResult
    public mutating func remove(tag: Tag) -> Bool {
        guard let idx = buffer.firstIndex(where: { $0.tag == tag }) else { return false }
        let isHeadRemoval = (idx == 0)
        buffer.remove(at: idx)

        if let first = deque.first, first.tag == tag {
            deque.removeFirst()
        } else if let dIdx = deque.firstIndex(where: { $0.tag == tag }) {
            deque.remove(at: dIdx)
        }

        // If a non-head entry was removed, rebuild the monotonic chain to restore invariants
        if !isHeadRemoval {
            rebuildDeque()
        }
        return true
    }

    /// Clears and purges all entries from the deque and buffer.
    public mutating func removeAll() {
        deque.removeAll()
        buffer.removeAll()
    }

    private mutating func rebuildDeque() {
        deque.removeAll()
        for entry in buffer {
            switch order {
            case .increasing:
                while let last = deque.last, last.element >= entry.element {
                    deque.removeLast()
                }
            case .decreasing:
                while let last = deque.last, last.element <= entry.element {
                    deque.removeLast()
                }
            }
            deque.append(entry)
        }
    }
}

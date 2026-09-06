//
//  BTree.swift
//  Tile38Swift
//
//  Created on 2026-09-05.
//

import Foundation

/// High-fanout, cache-friendly in-memory B-Tree in 100% pure Swift.
///
/// Stores sorted key-value pairs in contiguous node arrays with degree $B$ (default: 16).
/// Minimizes CPU L1/L2 cache misses compared to binary search trees, providing:
/// - $O(\log_B N)$ point lookups, insertions, and deletions
/// - $O(\log_B N + K)$ range scans (`scan(from:to:)`)
/// - In-order forward traversal conforming to `Sequence`
/// - Full value semantics via Copy-on-Write (COW)
public struct BTree<Key: Comparable & Sendable, Value: Sendable>: Sendable, Sequence {
    public typealias Element = (key: Key, value: Value)

    /// Minimum degree $B$. A non-root node contains at least $B - 1$ keys and at most $2B - 1$ keys.
    public let degree: Int

    /// Root node of the B-Tree.
    private var root: Node

    /// Total number of key-value pairs stored in the tree.
    public private(set) var count: Int

    /// Initializes an empty `BTree` with the specified minimum degree.
    ///
    /// - Parameter degree: Minimum degree parameter $B \ge 2$ (default: 16, resulting in max 31 keys per node).
    public init(degree: Int = 16) {
        precondition(degree >= 2, "BTree degree must be at least 2")
        self.degree = degree
        self.root = Node(isLeaf: true)
        self.count = 0
    }

    /// Indicates whether the tree contains zero elements.
    public var isEmpty: Bool { count == 0 }

    /// Maximum capacity of keys per node: $2B - 1$.
    private var maxKeys: Int { 2 * degree - 1 }

    /// Minimum keys required in a non-root node: $B - 1$.
    private var minKeys: Int { degree - 1 }

    /// Clears all elements from the tree.
    public mutating func clear() {
        self.root = Node(isLeaf: true)
        self.count = 0
    }

    // MARK: - Point Lookups

    /// Looks up the value associated with `key` in $O(\log_B N)$ time.
    ///
    /// - Parameter key: The lookup key.
    /// - Returns: The matching `Value`, or `nil` if the key is not present.
    public func find(key: Key) -> Value? {
        findHelper(node: root, key: key)
    }

    /// Subscript accessor for key-based retrieval and mutation.
    public subscript(key: Key) -> Value? {
        get { find(key: key) }
        set {
            if let val = newValue {
                insert(key: key, value: val)
            } else {
                remove(key: key)
            }
        }
    }

    /// Tests whether the specified key exists in the tree.
    ///
    /// - Parameter key: The lookup key.
    /// - Returns: `true` if present, `false` otherwise.
    public func contains(key: Key) -> Bool {
        find(key: key) != nil
    }

    private func findHelper(node: Node, key: Key) -> Value? {
        let idx = binarySearch(keys: node.keys, key: key)
        if idx < node.keys.count && node.keys[idx] == key {
            return node.values[idx]
        }
        if node.isLeaf {
            return nil
        }
        return findHelper(node: node.children[idx], key: key)
    }

    // MARK: - Minimum & Maximum

    /// Returns the smallest key-value pair in $O(\log_B N)$ time.
    public var min: Element? {
        guard count > 0 else { return nil }
        var curr = root
        while !curr.isLeaf {
            curr = curr.children[0]
        }
        return (curr.keys[0], curr.values[0])
    }

    /// Returns the largest key-value pair in $O(\log_B N)$ time.
    public var max: Element? {
        guard count > 0 else { return nil }
        var curr = root
        while !curr.isLeaf {
            curr = curr.children[curr.children.count - 1]
        }
        let lastIdx = curr.keys.count - 1
        return (curr.keys[lastIdx], curr.values[lastIdx])
    }

    // MARK: - Insertion

    /// Inserts or updates a key-value pair in $O(\log_B N)$ time.
    ///
    /// Uses proactive top-down splitting: any full node encountered on the downward path
    /// is split beforehand, ensuring that leaf insertions never cascade upward.
    ///
    /// - Parameters:
    ///   - key: The key to insert.
    ///   - value: The associated value.
    /// - Returns: The previous value associated with `key` if it was updated, or `nil` if newly inserted.
    @discardableResult
    public mutating func insert(key: Key, value: Value) -> Value? {
        ensureUniqueRoot()

        // If root is full, split it and create a new root
        if root.keys.count == maxKeys {
            let newRoot = Node(isLeaf: false)
            newRoot.children.append(root)
            splitChild(parent: newRoot, index: 0)
            self.root = newRoot
        }

        var isNewKey = false
        let oldVal = insertNonFull(node: root, key: key, value: value, isNewKey: &isNewKey)
        if isNewKey {
            count += 1
        }
        return oldVal
    }

    private mutating func insertNonFull(node: Node, key: Key, value: Value, isNewKey: inout Bool) -> Value? {
        var idx = binarySearch(keys: node.keys, key: key)

        if idx < node.keys.count && node.keys[idx] == key {
            // Key exists: update in place
            let prev = node.values[idx]
            node.values[idx] = value
            isNewKey = false
            return prev
        }

        if node.isLeaf {
            // Insert in sorted order within leaf
            node.keys.insert(key, at: idx)
            node.values.insert(value, at: idx)
            isNewKey = true
            return nil
        }

        // Internal node: check if child is full before descending
        if node.children[idx].keys.count == maxKeys {
            splitChild(parent: node, index: idx)
            if key == node.keys[idx] {
                let prev = node.values[idx]
                node.values[idx] = value
                isNewKey = false
                return prev
            } else if key > node.keys[idx] {
                idx += 1
            }
        }

        return insertNonFull(node: node.children[idx], key: key, value: value, isNewKey: &isNewKey)
    }

    /// Splits child node at `index` of `parent` into two half-nodes, promoting the median key.
    private func splitChild(parent: Node, index: Int) {
        let child = parent.children[index]
        let sibling = Node(isLeaf: child.isLeaf)

        let medianIndex = degree - 1
        let medianKey = child.keys[medianIndex]
        let medianVal = child.values[medianIndex]

        // Sibling gets keys from medianIndex + 1 to end
        sibling.keys = Array(child.keys[(medianIndex + 1)...])
        sibling.values = Array(child.values[(medianIndex + 1)...])
        child.keys = Array(child.keys[..<medianIndex])
        child.values = Array(child.values[..<medianIndex])

        if !child.isLeaf {
            sibling.children = Array(child.children[degree...])
            child.children = Array(child.children[..<degree])
        }

        parent.keys.insert(medianKey, at: index)
        parent.values.insert(medianVal, at: index)
        parent.children.insert(sibling, at: index + 1)
    }

    // MARK: - Deletion

    /// Removes a key and its associated value from the B-Tree in $O(\log_B N)$ time.
    ///
    /// - Parameter key: The key to delete.
    /// - Returns: The removed `Value`, or `nil` if not found.
    @discardableResult
    public mutating func remove(key: Key) -> Value? {
        guard count > 0 else { return nil }
        ensureUniqueRoot()

        let removed = removeHelper(node: root, key: key)
        if removed != nil {
            count -= 1
            // If root has 0 keys and has children, promote first child as root
            if root.keys.isEmpty && !root.isLeaf {
                self.root = root.children[0]
            }
        }
        return removed
    }

    private mutating func removeHelper(node: Node, key: Key) -> Value? {
        var idx = binarySearch(keys: node.keys, key: key)

        if idx < node.keys.count && node.keys[idx] == key {
            // Key is present in this node
            if node.isLeaf {
                node.keys.remove(at: idx)
                return node.values.remove(at: idx)
            } else {
                return removeFromNonLeaf(node: node, index: idx)
            }
        }

        if node.isLeaf {
            // Key not in tree
            return nil
        }

        // Ensure child has at least degree keys before descending
        if node.children[idx].keys.count < degree {
            fillChild(node: node, index: idx)
            // Recompute index since filling may have shifted children
            idx = binarySearch(keys: node.keys, key: key)
            if idx < node.keys.count && node.keys[idx] == key {
                if node.isLeaf {
                    node.keys.remove(at: idx)
                    return node.values.remove(at: idx)
                } else {
                    return removeFromNonLeaf(node: node, index: idx)
                }
            }
        }

        return removeHelper(node: node.children[idx], key: key)
    }

    private mutating func removeFromNonLeaf(node: Node, index: Int) -> Value? {
        let removedVal = node.values[index]
        let leftChild = node.children[index]
        let rightChild = node.children[index + 1]

        if leftChild.keys.count >= degree {
            // Replace with predecessor
            var curr = leftChild
            while !curr.isLeaf {
                curr = curr.children[curr.children.count - 1]
            }
            let predKey = curr.keys[curr.keys.count - 1]
            let predVal = curr.values[curr.values.count - 1]
            node.keys[index] = predKey
            node.values[index] = predVal
            _ = removeHelper(node: leftChild, key: predKey)
        } else if rightChild.keys.count >= degree {
            // Replace with successor
            var curr = rightChild
            while !curr.isLeaf {
                curr = curr.children[0]
            }
            let succKey = curr.keys[0]
            let succVal = curr.values[0]
            node.keys[index] = succKey
            node.values[index] = succVal
            _ = removeHelper(node: rightChild, key: succKey)
        } else {
            // Both children have degree - 1 keys: merge them
            mergeChildren(parent: node, index: index)
            _ = removeHelper(node: leftChild, key: node.keys.isEmpty ? leftChild.keys[degree - 1] : leftChild.keys[degree - 1])
        }

        return removedVal
    }

    private mutating func fillChild(node: Node, index: Int) {
        if index > 0 && node.children[index - 1].keys.count >= degree {
            borrowFromPrev(parent: node, index: index)
        } else if index < node.children.count - 1 && node.children[index + 1].keys.count >= degree {
            borrowFromNext(parent: node, index: index)
        } else {
            if index < node.children.count - 1 {
                mergeChildren(parent: node, index: index)
            } else {
                mergeChildren(parent: node, index: index - 1)
            }
        }
    }

    private func borrowFromPrev(parent: Node, index: Int) {
        let child = parent.children[index]
        let sibling = parent.children[index - 1]

        child.keys.insert(parent.keys[index - 1], at: 0)
        child.values.insert(parent.values[index - 1], at: 0)
        if !child.isLeaf {
            child.children.insert(sibling.children.removeLast(), at: 0)
        }

        parent.keys[index - 1] = sibling.keys.removeLast()
        parent.values[index - 1] = sibling.values.removeLast()
    }

    private func borrowFromNext(parent: Node, index: Int) {
        let child = parent.children[index]
        let sibling = parent.children[index + 1]

        child.keys.append(parent.keys[index])
        child.values.append(parent.values[index])
        if !child.isLeaf {
            child.children.append(sibling.children.removeFirst())
        }

        parent.keys[index] = sibling.keys.removeFirst()
        parent.values[index] = sibling.values.removeFirst()
    }

    private func mergeChildren(parent: Node, index: Int) {
        let left = parent.children[index]
        let right = parent.children.remove(at: index + 1)
        let key = parent.keys.remove(at: index)
        let val = parent.values.remove(at: index)

        left.keys.append(key)
        left.values.append(val)
        left.keys.append(contentsOf: right.keys)
        left.values.append(contentsOf: right.values)

        if !left.isLeaf {
            left.children.append(contentsOf: right.children)
        }
    }

    // MARK: - Range Scans

    /// Performs an in-order range scan between `from` and `to` inclusive.
    ///
    /// - Parameters:
    ///   - from: Starting key bound (inclusive). If `nil`, starts from `min`.
    ///   - to: Ending key bound (inclusive). If `nil`, continues through `max`.
    ///   - reverse: If `true`, returns items in descending order (default: `false`).
    /// - Returns: Array of `(key, value)` pairs in the requested order.
    public func scan(from: Key? = nil, to: Key? = nil, reverse: Bool = false) -> [Element] {
        var results: [Element] = []
        if reverse {
            scanReverseHelper(node: root, from: from, to: to, results: &results)
        } else {
            scanForwardHelper(node: root, from: from, to: to, results: &results)
        }
        return results
    }

    private func scanForwardHelper(node: Node, from: Key?, to: Key?, results: inout [Element]) {
        for i in 0..<node.keys.count {
            let key = node.keys[i]
            if !node.isLeaf {
                // If key is >= from, child[i] may contain matching elements
                if from == nil || key >= from! {
                    scanForwardHelper(node: node.children[i], from: from, to: to, results: &results)
                }
            }

            let afterFrom = from == nil || key >= from!
            let beforeTo = to == nil || key <= to!

            if afterFrom && beforeTo {
                results.append((key, node.values[i]))
            } else if to != nil && key > to! {
                return // Beyond upper bound
            }
        }

        if !node.isLeaf {
            let lastKey = node.keys.last!
            if to == nil || lastKey <= to! {
                scanForwardHelper(node: node.children[node.keys.count], from: from, to: to, results: &results)
            }
        }
    }

    private func scanReverseHelper(node: Node, from: Key?, to: Key?, results: inout [Element]) {
        if !node.isLeaf {
            let lastKey = node.keys.last!
            if to == nil || lastKey <= to! {
                scanReverseHelper(node: node.children[node.keys.count], from: from, to: to, results: &results)
            }
        }

        for i in (0..<node.keys.count).reversed() {
            let key = node.keys[i]
            let afterFrom = from == nil || key >= from!
            let beforeTo = to == nil || key <= to!

            if afterFrom && beforeTo {
                results.append((key, node.values[i]))
            } else if from != nil && key < from! {
                return
            }

            if !node.isLeaf {
                if to == nil || key <= to! {
                    scanReverseHelper(node: node.children[i], from: from, to: to, results: &results)
                }
            }
        }
    }

    // MARK: - Sequence Conformance

    public func makeIterator() -> AnyIterator<Element> {
        var items: [Element] = []
        scanForwardHelper(node: root, from: nil, to: nil, results: &items)
        var idx = 0
        return AnyIterator {
            if idx < items.count {
                let el = items[idx]
                idx += 1
                return el
            }
            return nil
        }
    }

    // MARK: - Utility Functions

    /// Binary search returning index of first key $\ge$ search key.
    private func binarySearch(keys: [Key], key: Key) -> Int {
        var low = 0
        var high = keys.count

        while low < high {
            let mid = low + (high - low) / 2
            if keys[mid] < key {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private mutating func ensureUniqueRoot() {
        if !isKnownUniquelyReferenced(&root) {
            self.root = root.deepCopy()
        }
    }

    // MARK: - Internal Node Representation

    private final class Node: @unchecked Sendable {
        let isLeaf: Bool
        var keys: [Key]
        var values: [Value]
        var children: [Node]

        init(isLeaf: Bool) {
            self.isLeaf = isLeaf
            self.keys = []
            self.values = []
            self.children = []
        }

        func deepCopy() -> Node {
            let copy = Node(isLeaf: self.isLeaf)
            copy.keys = self.keys
            copy.values = self.values
            copy.children = self.children.map { $0.deepCopy() }
            return copy
        }
    }
}

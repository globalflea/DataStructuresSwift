import Foundation

/// Internal node representing a segment in a hierarchical variable path trie.
final class PathTrieNode: @unchecked Sendable {
    /// Set of rule names that depend directly on this path segment.
    var ruleNames: Set<String> = []
    /// Child path segments mapped by token string.
    var children: [String: PathTrieNode] = [:]
}

/// A prefix trie data structure optimized for fast variable-path dependency lookups.
///
/// Instead of performing linear string scans and prefix checks across all indexed paths,
/// `PathTrie` maps path segments (e.g. `["Order", "Item", "Price"]`) into a tree structure.
///
/// When a fact path mutates during rule execution, `findInvalidatedRules(for:)` navigates the trie
/// in O(K) time (where K is the path depth) to simultaneously resolve:
/// 1. Rules reading the exact path (exact match).
/// 2. Rules reading ancestor objects along the path (parent invalidation).
/// 3. Rules reading descendant properties in the sub-tree (child invalidation).
public final class PathTrie: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let root = PathTrieNode()

    /// Total number of indexed paths in the trie.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
    private var _count: Int = 0

    public init() {}

    /// Pre-populates the trie from a dependency index mapping paths to rule sets.
    ///
    /// - Parameter index: A dictionary mapping canonical variable paths to set of rule names.
    public convenience init(index: [String: Set<String>]) {
        self.init()
        for (path, rules) in index {
            for rule in rules {
                insert(path: path, ruleName: rule)
            }
        }
    }

    /// Inserts a variable path dependency for a designated rule.
    ///
    /// - Parameters:
    ///   - path: The dot-separated or bracketed variable path string (e.g. `"Order.Item.Price"`).
    ///   - ruleName: The name of the rule that references this variable path.
    public func insert(path: String, ruleName: String) {
        let tokens = Self.tokenizePath(path)
        guard !tokens.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        var current = root
        for token in tokens {
            if let child = current.children[token] {
                current = child
            } else {
                let newNode = PathTrieNode()
                current.children[token] = newNode
                current = newNode
            }
        }
        let inserted = current.ruleNames.insert(ruleName).inserted
        if inserted {
            _count += 1
        }
    }

    /// Finds all rule names invalidated by a mutation to the specified variable path.
    ///
    /// Traverses the trie in O(K + D) time, collecting:
    /// - Ancestor rules registered at nodes along the path to the target.
    /// - Exact match rules registered at the target node.
    /// - Descendant rules registered in the entire subtree under the target node.
    ///
    /// - Parameter modifiedPath: The modified variable path string.
    /// - Returns: The set of rule names that depend on the mutated path.
    public func findInvalidatedRules(for modifiedPath: String) -> Set<String> {
        let tokens = Self.tokenizePath(modifiedPath)
        guard !tokens.isEmpty else { return [] }

        lock.lock()
        defer { lock.unlock() }

        var invalidated: Set<String> = []
        var current = root

        // 1. Walk down the path tokens, collecting parent rules at each step
        for token in tokens {
            if let child = current.children[token] {
                current = child
                invalidated.formUnion(current.ruleNames)
            } else {
                // If a path segment is not present, return any ancestor rules collected so far
                return invalidated
            }
        }

        // 2. Collect all descendant rules in the subtree below the target node
        func collectSubtree(_ node: PathTrieNode) {
            invalidated.formUnion(node.ruleNames)
            for child in node.children.values {
                collectSubtree(child)
            }
        }

        for child in current.children.values {
            collectSubtree(child)
        }

        return invalidated
    }

    /// Clears all nodes and reset the trie.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        root.ruleNames.removeAll()
        root.children.removeAll()
        _count = 0
    }

    /// Tokenizes a canonical dot-separated and bracketed variable path into structured segments.
    ///
    /// Handles member accesses (`Order.Item`), bracketed indices (`[0]`, `[$1]`), and method signatures.
    ///
    /// - Parameter path: The raw variable path string.
    /// - Returns: An array of path segment tokens.
    public static func tokenizePath(_ path: String) -> [String] {
        guard !path.isEmpty else { return [] }
        var tokens: [String] = []
        var current = ""
        var inBracket = false
        var inParen = false

        for char in path {
            if char == "[" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                current.append(char)
                inBracket = true
            } else if char == "]" {
                current.append(char)
                tokens.append(current)
                current = ""
                inBracket = false
            } else if char == "(" {
                current.append(char)
                inParen = true
            } else if char == ")" {
                current.append(char)
                inParen = false
            } else if char == "." && !inBracket && !inParen {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}

// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// Directed edge between two nodes in a graph.
public struct DAGEdge: Sendable, Hashable {
    public var from: String
    public var to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}

/// Topological layering and rank assignment solver for Directed Acyclic Graphs.
public enum DAGLayeringSolver {

    /// Computes discrete topological layer ranks $[0, 1, 2, \dots]$ for all nodes in the directed graph.
    ///
    /// Handles cyclic dependencies gracefully via Tarjan DFS back-edge detection, reversing
    /// feedback arcs to produce a strictly acyclic DAG before calculating longest-path ranks.
    ///
    /// - Parameters:
    ///   - nodeIds: Collection of unique node identifiers.
    ///   - edges: Directed relationships $(u \to v)$ connecting nodes.
    /// - Returns: A dictionary mapping node IDs to zero-based topological layer rank integers.
    /// - Complexity: $O(|V| + |E|)$ linear time and space.
    public static func assignLayers(
        nodeIds: [String],
        edges: [DAGEdge]
    ) -> [String: Int] {
        guard !nodeIds.isEmpty else { return [:] }

        // 1. Build adjacency
        var outgoing: [String: Set<String>] = [:]
        var incoming: [String: Set<String>] = [:]
        for id in nodeIds {
            outgoing[id] = []
            incoming[id] = []
        }
        for edge in edges {
            outgoing[edge.from]?.insert(edge.to)
            incoming[edge.to]?.insert(edge.from)
        }

        // 2. Cycle breaking via DFS (Tarjan back-edge detection)
        var visited: [String: Int] = [:] // 0: unvisited, 1: visiting, 2: visited
        var acyclicOutgoing: [String: Set<String>] = outgoing
        var acyclicIncoming: [String: Set<String>] = incoming

        func dfs(u: String) {
            visited[u] = 1
            if let neighbors = outgoing[u] {
                for v in neighbors {
                    let vState = visited[v]
                    if vState == 1 {
                        // Back-edge detected: reverse it
                        acyclicOutgoing[u]?.remove(v)
                        acyclicIncoming[v]?.remove(u)
                        acyclicOutgoing[v]?.insert(u)
                        acyclicIncoming[u]?.insert(v)
                    } else if vState == nil || vState == 0 {
                        dfs(u: v)
                    }
                }
            }
            visited[u] = 2
        }

        for id in nodeIds {
            let state = visited[id]
            if state == nil || state == 0 {
                dfs(u: id)
            }
        }

        // 3. Longest path layering
        var ranks: [String: Int] = [:]
        var inDegree: [String: Int] = [:]
        for id in nodeIds {
            inDegree[id] = acyclicIncoming[id]?.count ?? 0
            ranks[id] = 0
        }

        var queue: [String] = nodeIds.filter { (inDegree[$0] ?? 0) == 0 }

        while !queue.isEmpty {
            let u = queue.removeFirst()
            let currentRank = ranks[u] ?? 0

            if let neighbors = acyclicOutgoing[u] {
                for v in neighbors {
                    let prevRank = ranks[v] ?? 0
                    ranks[v] = max(prevRank, currentRank + 1)
                    let deg = (inDegree[v] ?? 1) - 1
                    inDegree[v] = deg
                    if deg == 0 {
                        queue.append(v)
                    }
                }
            }
        }

        return ranks
    }
}

// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation
import VectorGeometry

/// A particle node in the force-directed graph simulation.
public struct ForceDirectedNode: Sendable, Hashable, Identifiable {
    public var id: String
    public var position: Point2D
    public var velocity: Vector2D
    public var force: Vector2D
    public var mass: Double
    public var isFixed: Bool

    public init(
        id: String,
        position: Point2D = .zero,
        velocity: Vector2D = .zero,
        mass: Double = 1.0,
        isFixed: Bool = false
    ) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.force = .zero
        self.mass = max(0.1, mass)
        self.isFixed = isFixed
    }
}

/// An elastic link connecting two nodes in the force-directed graph simulation.
public struct ForceDirectedEdge: Sendable, Hashable {
    public var sourceId: String
    public var targetId: String
    public var weight: Double
    public var targetDistance: Double

    public init(sourceId: String, targetId: String, weight: Double = 1.0, targetDistance: Double = 50.0) {
        self.sourceId = sourceId
        self.targetId = targetId
        self.weight = max(0.01, weight)
        self.targetDistance = max(1.0, targetDistance)
    }
}

/// Configuration parameters governing force-directed physics dynamics.
public struct ForceDirectedConfiguration: Sendable, Equatable {
    public var springStrength: Double
    public var repulsionStrength: Double
    public var centerGravity: Double
    public var damping: Double
    public var timeStep: Double
    public var minDistance: Double
    public var maxDistance: Double
    public var center: Point2D

    public init(
        springStrength: Double = 0.05,
        repulsionStrength: Double = 1000.0,
        centerGravity: Double = 0.01,
        damping: Double = 0.85,
        timeStep: Double = 0.5,
        minDistance: Double = 5.0,
        maxDistance: Double = 500.0,
        center: Point2D = .zero
    ) {
        self.springStrength = springStrength
        self.repulsionStrength = repulsionStrength
        self.centerGravity = centerGravity
        self.damping = damping
        self.timeStep = timeStep
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.center = center
    }
}

/// High-performance force-directed graph simulator.
public final class ForceDirectedSimulator: @unchecked Sendable {
    public var nodes: [String: ForceDirectedNode]
    public var edges: [ForceDirectedEdge]
    public var configuration: ForceDirectedConfiguration

    public init(
        nodes: [ForceDirectedNode] = [],
        edges: [ForceDirectedEdge] = [],
        configuration: ForceDirectedConfiguration = .init()
    ) {
        var nodeMap: [String: ForceDirectedNode] = [:]
        for node in nodes {
            nodeMap[node.id] = node
        }
        self.nodes = nodeMap
        self.edges = edges
        self.configuration = configuration
    }

    /// Advances the simulation by a single discrete time-step $\Delta t$.
    ///
    /// Executes the three-phase physical kinematics pipeline:
    /// 1. Coulomb electrostatic pair repulsion: $\vec{F}_r = \frac{k_r^2}{d^2} \hat{r}$
    /// 2. Hooke spring elastic edge attraction: $\vec{F}_a = -k_s (d - l_0) \hat{r}$
    /// 3. Semi-implicit Euler-Cromer integration with velocity damping $\gamma$:
    ///    $$\vec{v}_{t+\Delta t} = (\vec{v}_t + \frac{\vec{F}}{m} \Delta t) \cdot \gamma$$
    ///    $$\vec{p}_{t+\Delta t} = \vec{p}_t + \vec{v}_{t+\Delta t} \Delta t$$
    ///
    /// - Complexity: $O(N^2 + E)$ for all-pairs force accumulation.
    public func step() {
        let nodeKeys = Array(nodes.keys)
        let n = nodeKeys.count
        guard n > 1 else { return }

        // Reset forces & apply center gravity
        for key in nodeKeys {
            guard var node = nodes[key] else { continue }
            let dCenter = configuration.center - node.position
            node.force = dCenter * configuration.centerGravity * node.mass
            nodes[key] = node
        }

        // 1. Coulomb Repulsion (all pairs)
        for i in 0..<n {
            let idA = nodeKeys[i]
            guard var nodeA = nodes[idA] else { continue }

            for j in (i + 1)..<n {
                let idB = nodeKeys[j]
                guard var nodeB = nodes[idB] else { continue }

                let delta = nodeA.position - nodeB.position
                let dist = max(configuration.minDistance, min(configuration.maxDistance, delta.magnitude))
                let forceMagnitude = configuration.repulsionStrength / (dist * dist)
                let forceVector = delta.normalized() * forceMagnitude

                if !nodeA.isFixed {
                    nodeA.force += forceVector
                }
                if !nodeB.isFixed {
                    nodeB.force -= forceVector
                }

                nodes[idB] = nodeB
            }
            nodes[idA] = nodeA
        }

        // 2. Hooke Spring Attraction (along edges)
        for edge in edges {
            guard var source = nodes[edge.sourceId], var target = nodes[edge.targetId] else { continue }

            let delta = target.position - source.position
            let dist = max(1e-4, delta.magnitude)
            let displacement = dist - edge.targetDistance
            let forceMagnitude = displacement * configuration.springStrength * edge.weight
            let forceVector = delta.normalized() * forceMagnitude

            if !source.isFixed {
                source.force += forceVector
            }
            if !target.isFixed {
                target.force -= forceVector
            }

            nodes[edge.sourceId] = source
            nodes[edge.targetId] = target
        }

        // 3. Integrate Velocity & Position (Euler-Cromer)
        for key in nodeKeys {
            guard var node = nodes[key] else { continue }
            if node.isFixed {
                node.velocity = .zero
                node.force = .zero
                nodes[key] = node
                continue
            }

            let acceleration = node.force / node.mass
            node.velocity = (node.velocity + acceleration * configuration.timeStep) * configuration.damping
            node.position += node.velocity * configuration.timeStep
            node.force = .zero
            nodes[key] = node
        }
    }

    /// Runs the simulation for a prescribed number of discrete equilibrium iterations.
    ///
    /// - Parameter iterations: The number of discrete integration steps to execute (default `50`).
    /// - Complexity: $O(I \cdot (N^2 + E))$ where $I$ is iteration count.
    public func run(iterations: Int = 50) {
        for _ in 0..<iterations {
            step()
        }
    }
}

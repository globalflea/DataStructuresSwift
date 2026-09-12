// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Testing
import Foundation
import VectorGeometry
@testable import VectorLayout

@Suite("VectorLayout Foundation Tests")
struct VectorLayoutTests {

    @Test("TidyTreeSolver Buchheim-Walker layout across orientations")
    func testTidyTreeLayout() {
        // Build a sample tree: Root with 2 children, child 1 has 2 leaves
        let root = TidyTreeNode<String>(id: "root", width: 40, height: 20)
        let child1 = TidyTreeNode<String>(id: "c1", width: 30, height: 20)
        let child2 = TidyTreeNode<String>(id: "c2", width: 30, height: 20)
        let leaf1 = TidyTreeNode<String>(id: "l1", width: 25, height: 20)
        let leaf2 = TidyTreeNode<String>(id: "l2", width: 25, height: 20)

        child1.addChild(leaf1)
        child1.addChild(leaf2)
        root.addChild(child1)
        root.addChild(child2)

        // 1. TopToBottom
        TidyTreeSolver.layout(root: root, configuration: .init(orientation: .topToBottom, levelSeparation: 50))
        #expect(root.y == 0.0)
        #expect(child1.y == 50.0)
        #expect(child2.y == 50.0)
        #expect(leaf1.y == 100.0)
        #expect(leaf2.y == 100.0)
        #expect(child1.x < child2.x)
        #expect(leaf1.x < leaf2.x)

        // 2. LeftToRight
        TidyTreeSolver.layout(root: root, configuration: .init(orientation: .leftToRight, levelSeparation: 60))
        #expect(root.x == 0.0)
        #expect(child1.x == 60.0)
        #expect(child2.x == 60.0)
        #expect(leaf1.x == 120.0)
        #expect(leaf2.x == 120.0)

        // 3. BottomToTop & RightToLeft & Radial
        TidyTreeSolver.layout(root: root, configuration: .init(orientation: .bottomToTop))
        #expect(child1.y < 0.0)

        TidyTreeSolver.layout(root: root, configuration: .init(orientation: .rightToLeft))
        #expect(child1.x < 0.0)

        TidyTreeSolver.layout(root: root, configuration: .init(orientation: .radial))
        #expect(!root.x.isNaN && !root.y.isNaN)
    }

    @Test("ForceDirectedSimulator physics dynamics, spring attraction, and repulsion")
    func testForceDirectedSimulation() {
        let n1 = ForceDirectedNode(id: "n1", position: Point2D(0, 0))
        let n2 = ForceDirectedNode(id: "n2", position: Point2D(1, 0)) // very close: strong repulsion
        let n3 = ForceDirectedNode(id: "n3", position: Point2D(500, 500), isFixed: true)

        let edge = ForceDirectedEdge(sourceId: "n1", targetId: "n2", targetDistance: 50.0)

        let sim = ForceDirectedSimulator(
            nodes: [n1, n2, n3],
            edges: [edge],
            configuration: .init(springStrength: 0.1, repulsionStrength: 500.0, centerGravity: 0.01)
        )

        let initialDist = sim.nodes["n1"]!.position.distance(to: sim.nodes["n2"]!.position)

        // Run simulation
        sim.run(iterations: 30)

        let finalDist = sim.nodes["n1"]!.position.distance(to: sim.nodes["n2"]!.position)
        #expect(finalDist > initialDist, "Repulsion should have pushed n1 and n2 further apart")

        // Fixed node should not have moved
        #expect(sim.nodes["n3"]!.position == Point2D(500, 500))
    }

    @Test("DAGLayeringSolver topological ranking and cycle resolution")
    func testDAGLayering() {
        // Diamond DAG: A -> B, A -> C, B -> D, C -> D
        let diamondNodes = ["A", "B", "C", "D"]
        let diamondEdges = [
            DAGEdge(from: "A", to: "B"),
            DAGEdge(from: "A", to: "C"),
            DAGEdge(from: "B", to: "D"),
            DAGEdge(from: "C", to: "D")
        ]

        let layers = DAGLayeringSolver.assignLayers(nodeIds: diamondNodes, edges: diamondEdges)
        #expect(layers["A"] == 0)
        #expect(layers["B"] == 1)
        #expect(layers["C"] == 1)
        #expect(layers["D"] == 2)

        // Cyclic graph: X -> Y -> Z -> X
        let cycleNodes = ["X", "Y", "Z"]
        let cycleEdges = [
            DAGEdge(from: "X", to: "Y"),
            DAGEdge(from: "Y", to: "Z"),
            DAGEdge(from: "Z", to: "X")
        ]
        let cycleLayers = DAGLayeringSolver.assignLayers(nodeIds: cycleNodes, edges: cycleEdges)
        #expect(cycleLayers.count == 3)
        #expect(cycleLayers["X"] != nil)

        #expect(DAGLayeringSolver.assignLayers(nodeIds: [], edges: []).isEmpty)

        let e1 = DAGEdge(from: "A", to: "B")
        let e2 = DAGEdge(from: "A", to: "B")
        #expect(e1 == e2)
        #expect(e1.hashValue == e2.hashValue)
        let edgeSet: Set<DAGEdge> = [e1, e2]
        #expect(edgeSet.count == 1)
    }

    @Test("TidyTree deep multi-branch contour shifting and subtree separation")
    func testTidyTreeContourShifting() {
        // Construct a tree where left and right subtrees have multiple levels that conflict
        // Root -> A, B
        // A -> A1, A2
        // A2 -> A21, A22
        // B -> B1, B2
        // B1 -> B11, B12
        let root = TidyTreeNode<String>(id: "root")
        let a = TidyTreeNode<String>(id: "A")
        let b = TidyTreeNode<String>(id: "B")
        let a1 = TidyTreeNode<String>(id: "A1")
        let a2 = TidyTreeNode<String>(id: "A2")
        let a21 = TidyTreeNode<String>(id: "A21")
        let a22 = TidyTreeNode<String>(id: "A22")
        let b1 = TidyTreeNode<String>(id: "B1")
        let b2 = TidyTreeNode<String>(id: "B2")
        let b11 = TidyTreeNode<String>(id: "B11")
        let b12 = TidyTreeNode<String>(id: "B12")

        a2.addChild(a21)
        a2.addChild(a22)
        a.addChild(a1)
        a.addChild(a2)

        b1.addChild(b11)
        b1.addChild(b12)
        b.addChild(b1)
        b.addChild(b2)

        root.addChild(a)
        root.addChild(b)

        TidyTreeSolver.layout(root: root, configuration: .init(orientation: .topToBottom, subtreeSeparation: 50.0))

        #expect(a.x < b.x)
        #expect(a22.x < b11.x, "Subtrees must not overlap at depth 3")
        #expect(b11.x - a22.x >= 50.0)

        // Single root tree
        let single = TidyTreeNode<String>(id: "lone")
        TidyTreeSolver.layout(root: single)
        #expect(single.x == 0.0 && single.y == 0.0)
    }
}

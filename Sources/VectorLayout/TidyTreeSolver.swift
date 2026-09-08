// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation
import VectorGeometry

/// Orientation mode for tidy tree rendering.
public enum TreeOrientation: Sendable, Hashable, Equatable, Codable {
    case topToBottom
    case bottomToTop
    case leftToRight
    case rightToLeft
    case radial
}

/// A generic tree node for Buchheim-Walker tidy tree layout computation.
public final class TidyTreeNode<Data>: @unchecked Sendable {
    public var id: String
    public var data: Data?
    public var children: [TidyTreeNode<Data>]
    public weak var parent: TidyTreeNode<Data>?

    public var width: Double
    public var height: Double
    public var x: Double = 0.0
    public var y: Double = 0.0

    // Internal Buchheim-Walker working variables
    var prelim: Double = 0.0
    var mod: Double = 0.0
    var thread: TidyTreeNode<Data>?
    var ancestor: TidyTreeNode<Data>?
    var change: Double = 0.0
    var shift: Double = 0.0
    var number: Int = 0

    public init(
        id: String,
        data: Data? = nil,
        width: Double = 40.0,
        height: Double = 40.0,
        children: [TidyTreeNode<Data>] = []
    ) {
        self.id = id
        self.data = data
        self.width = width
        self.height = height
        self.children = children
        self.ancestor = self
        for child in children {
            child.parent = self
        }
    }

    public func addChild(_ child: TidyTreeNode<Data>) {
        children.append(child)
        child.parent = self
    }
}

/// Configuration options for the Buchheim-Walker tidy tree algorithm.
public struct TidyTreeConfiguration: Sendable, Equatable {
    public var orientation: TreeOrientation
    public var siblingSeparation: Double
    public var subtreeSeparation: Double
    public var levelSeparation: Double

    public init(
        orientation: TreeOrientation = .leftToRight,
        siblingSeparation: Double = 20.0,
        subtreeSeparation: Double = 40.0,
        levelSeparation: Double = 60.0
    ) {
        self.orientation = orientation
        self.siblingSeparation = siblingSeparation
        self.subtreeSeparation = subtreeSeparation
        self.levelSeparation = levelSeparation
    }
}

/// Buchheim-Walker $O(N)$ tidy tree layout solver.
public enum TidyTreeSolver {

    /// Executes Buchheim-Walker layout on the root node hierarchy and mutates `x` and `y` coordinates.
    public static func layout<Data>(
        root: TidyTreeNode<Data>,
        configuration: TidyTreeConfiguration = .init()
    ) {
        // Initialize working variables
        initNodes(node: root)

        // Pass 1: Post-order traversal computing preliminary coordinates and shifts
        firstWalk(node: root, config: configuration)

        // Pass 2: Pre-order traversal accumulating modifier offsets
        secondWalk(node: root, modSum: -root.prelim, depth: 0, config: configuration)

        // Pass 3: Orientation transformation
        applyOrientation(node: root, config: configuration)
    }

    private static func initNodes<Data>(node: TidyTreeNode<Data>) {
        node.prelim = 0.0
        node.mod = 0.0
        node.thread = nil
        node.ancestor = node
        node.change = 0.0
        node.shift = 0.0

        for (idx, child) in node.children.enumerated() {
            child.parent = node
            child.number = idx
            initNodes(node: child)
        }
    }

    private static func firstWalk<Data>(
        node: TidyTreeNode<Data>,
        config: TidyTreeConfiguration
    ) {
        if node.children.isEmpty {
            if let leftSibling = leftSibling(of: node) {
                node.prelim = leftSibling.prelim + (leftSibling.width + node.width) * 0.5 + config.siblingSeparation
            } else {
                node.prelim = 0.0
            }
        } else {
            var defaultAncestor = node.children.first!
            for child in node.children {
                firstWalk(node: child, config: config)
                defaultAncestor = apportion(node: child, defaultAncestor: defaultAncestor, config: config)
            }
            executeShifts(node: node)

            let firstChild = node.children.first!
            let lastChild = node.children.last!
            let midpoint = (firstChild.prelim + lastChild.prelim) * 0.5

            if let leftSibling = leftSibling(of: node) {
                node.prelim = leftSibling.prelim + (leftSibling.width + node.width) * 0.5 + config.siblingSeparation
                node.mod = node.prelim - midpoint
            } else {
                node.prelim = midpoint
            }
        }
    }

    private static func apportion<Data>(
        node: TidyTreeNode<Data>,
        defaultAncestor: TidyTreeNode<Data>,
        config: TidyTreeConfiguration
    ) -> TidyTreeNode<Data> {
        guard let leftSibling = leftSibling(of: node), let firstChild = node.parent?.children.first else {
            return defaultAncestor
        }

        var vip: TidyTreeNode<Data>? = node
        var vop: TidyTreeNode<Data>? = node
        var vim: TidyTreeNode<Data>? = leftSibling
        var vom: TidyTreeNode<Data>? = firstChild

        var sip = node.mod
        var sop = node.mod
        var sim = leftSibling.mod
        var som = firstChild.mod

        var currentAncestor = defaultAncestor

        while let nextVim = nextRight(node: vim), let nextVip = nextLeft(node: vip) {
            vim = nextVim
            vip = nextVip
            vom = nextLeft(node: vom)
            vop = nextRight(node: vop)

            vop?.ancestor = node

            let shift = (nextVim.prelim + sim) - (nextVip.prelim + sip) +
                (nextVim.width + nextVip.width) * 0.5 + config.subtreeSeparation

            if shift > 0 {
                let ancestorNode = ancestor(vim: nextVim, node: node, defaultAncestor: currentAncestor)
                moveSubtree(wl: ancestorNode, wr: node, shift: shift)
                sip += shift
                sop += shift
            }

            sim += nextVim.mod
            sip += nextVip.mod
            if let vomNode = vom { som += vomNode.mod }
            if let vopNode = vop { sop += vopNode.mod }
        }

        if let nextVim = nextRight(node: vim), nextRight(node: vop) == nil {
            vop?.thread = nextVim
            vop?.mod += sim - sop
        }

        if let nextVip = nextLeft(node: vip), nextLeft(node: vom) == nil {
            vom?.thread = nextVip
            vom?.mod += sip - som
            currentAncestor = node
        }

        return currentAncestor
    }

    private static func moveSubtree<Data>(
        wl: TidyTreeNode<Data>,
        wr: TidyTreeNode<Data>,
        shift: Double
    ) {
        let subtrees = Double(wr.number - wl.number)
        if subtrees > 0 {
            wr.change -= shift / subtrees
            wr.shift += shift
            wl.change += shift / subtrees
            wr.prelim += shift
            wr.mod += shift
        }
    }

    private static func executeShifts<Data>(node: TidyTreeNode<Data>) {
        var shift = 0.0
        var change = 0.0
        for child in node.children.reversed() {
            child.prelim += shift
            child.mod += shift
            change += child.change
            shift += child.shift + change
        }
    }

    private static func secondWalk<Data>(
        node: TidyTreeNode<Data>,
        modSum: Double,
        depth: Double,
        config: TidyTreeConfiguration
    ) {
        node.x = node.prelim + modSum
        node.y = depth * config.levelSeparation

        for child in node.children {
            secondWalk(node: child, modSum: modSum + node.mod, depth: depth + 1.0, config: config)
        }
    }

    private static func applyOrientation<Data>(
        node: TidyTreeNode<Data>,
        config: TidyTreeConfiguration
    ) {
        transformRecursive(node: node, config: config)
    }

    private static func transformRecursive<Data>(
        node: TidyTreeNode<Data>,
        config: TidyTreeConfiguration
    ) {
        switch config.orientation {
        case .topToBottom:
            break
        case .bottomToTop:
            node.y = -node.y
        case .leftToRight:
            let temp = node.x
            node.x = node.y
            node.y = temp
        case .rightToLeft:
            let temp = node.x
            node.x = -node.y
            node.y = temp
        case .radial:
            let radius = node.y
            let angle = node.x * 0.01 // normalized radial angle
            node.x = radius * cos(angle)
            node.y = radius * sin(angle)
        }

        for child in node.children {
            transformRecursive(node: child, config: config)
        }
    }

    private static func leftSibling<Data>(of node: TidyTreeNode<Data>) -> TidyTreeNode<Data>? {
        guard let parent = node.parent, node.number > 0 else { return nil }
        return parent.children[node.number - 1]
    }

    private static func nextLeft<Data>(node: TidyTreeNode<Data>?) -> TidyTreeNode<Data>? {
        guard let node = node else { return nil }
        return node.children.first ?? node.thread
    }

    private static func nextRight<Data>(node: TidyTreeNode<Data>?) -> TidyTreeNode<Data>? {
        guard let node = node else { return nil }
        return node.children.last ?? node.thread
    }

    private static func ancestor<Data>(
        vim: TidyTreeNode<Data>,
        node: TidyTreeNode<Data>,
        defaultAncestor: TidyTreeNode<Data>
    ) -> TidyTreeNode<Data> {
        if let anc = vim.ancestor, anc.parent === node.parent {
            return anc
        }
        return defaultAncestor
    }
}

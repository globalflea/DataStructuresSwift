// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// Insets applied to the edges of a 2D rectangle.
public struct EdgeInsets2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public static let zero = EdgeInsets2D(top: 0, left: 0, bottom: 0, right: 0)

    @inlinable
    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    @inlinable
    public init(all: Double) {
        self.init(top: all, left: all, bottom: all, right: all)
    }

    @inlinable
    public init(horizontal: Double, vertical: Double) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    @inlinable
    public var horizontalTotal: Double {
        left + right
    }

    @inlinable
    public var verticalTotal: Double {
        top + bottom
    }

    public var description: String {
        "EdgeInsets2D(top: \(top), left: \(left), bottom: \(bottom), right: \(right))"
    }
}

// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// An axis-aligned 2D rectangle specified by origin and size.
public struct Rect2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var origin: Point2D
    public var size: Size2D

    public static let zero = Rect2D(origin: .zero, size: .zero)

    /// Primary initializer with automatic negative dimension normalization.
    public init(x: Double, y: Double, width: Double, height: Double) {
        var ox = x
        var oy = y
        var w = width
        var h = height

        if w < 0 {
            ox += w
            w = abs(w)
        }
        if h < 0 {
            oy += h
            h = abs(h)
        }

        self.origin = Point2D(x: ox, y: oy)
        self.size = Size2D(width: w, height: h)
    }

    @inlinable
    public init(origin: Point2D, size: Size2D) {
        self.init(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }

    /// Creates a rectangle centered at a given point.
    public init(center: Point2D, size: Size2D) {
        let origin = Point2D(x: center.x - size.width / 2, y: center.y - size.height / 2)
        self.init(origin: origin, size: size)
    }

    /// Creates a bounding rectangle encompassing two opposing corner points.
    public init(p1: Point2D, p2: Point2D) {
        let minX = min(p1.x, p2.x)
        let minY = min(p1.y, p2.y)
        let maxX = max(p1.x, p2.x)
        let maxY = max(p1.y, p2.y)
        self.init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Bounds & Anchors

    @inlinable public var x: Double { origin.x }
    @inlinable public var y: Double { origin.y }
    @inlinable public var width: Double { size.width }
    @inlinable public var height: Double { size.height }

    @inlinable public var minX: Double { origin.x }
    @inlinable public var midX: Double { origin.x + size.width * 0.5 }
    @inlinable public var maxX: Double { origin.x + size.width }

    @inlinable public var minY: Double { origin.y }
    @inlinable public var midY: Double { origin.y + size.height * 0.5 }
    @inlinable public var maxY: Double { origin.y + size.height }

    @inlinable public var center: Point2D { Point2D(x: midX, y: midY) }

    @inlinable public var topLeft: Point2D { Point2D(x: minX, y: minY) }
    @inlinable public var topRight: Point2D { Point2D(x: maxX, y: minY) }
    @inlinable public var bottomLeft: Point2D { Point2D(x: minX, y: maxY) }
    @inlinable public var bottomRight: Point2D { Point2D(x: maxX, y: maxY) }

    @inlinable public var topMiddle: Point2D { Point2D(x: midX, y: minY) }
    @inlinable public var bottomMiddle: Point2D { Point2D(x: midX, y: maxY) }
    @inlinable public var leftMiddle: Point2D { Point2D(x: minX, y: midY) }
    @inlinable public var rightMiddle: Point2D { Point2D(x: maxX, y: midY) }

    // MARK: - Containment & Intersection

    /// Checks whether the point lies within or on the boundary of the rectangle.
    @inlinable
    public func contains(_ point: Point2D) -> Bool {
        point.x >= minX - 1e-9 && point.x <= maxX + 1e-9 &&
        point.y >= minY - 1e-9 && point.y <= maxY + 1e-9
    }

    @inlinable
    public func contains(point: Point2D) -> Bool {
        contains(point)
    }

    /// Checks whether this rectangle completely contains another rectangle.
    @inlinable
    public func contains(_ other: Rect2D) -> Bool {
        other.minX >= minX - 1e-9 && other.maxX <= maxX + 1e-9 &&
        other.minY >= minY - 1e-9 && other.maxY <= maxY + 1e-9
    }

    @inlinable
    public func contains(rect: Rect2D) -> Bool {
        contains(rect)
    }

    /// Checks whether this rectangle intersects another rectangle.
    @inlinable
    public func intersects(_ other: Rect2D) -> Bool {
        !(other.minX > maxX || other.maxX < minX ||
          other.minY > maxY || other.maxY < minY)
    }

    @inlinable
    public func intersects(rect: Rect2D) -> Bool {
        intersects(rect)
    }

    /// Returns the intersecting sub-rectangle, or nil if disjoint.
    public func intersection(with other: Rect2D) -> Rect2D? {
        guard intersects(other) else { return nil }
        let nx = max(minX, other.minX)
        let ny = max(minY, other.minY)
        let nw = min(maxX, other.maxX) - nx
        let nh = min(maxY, other.maxY) - ny
        guard nw >= 0 && nh >= 0 else { return nil }
        return Rect2D(x: nx, y: ny, width: nw, height: nh)
    }

    /// Returns the smallest bounding box containing both rectangles.
    @inlinable
    public func union(with other: Rect2D) -> Rect2D {
        let nx = min(minX, other.minX)
        let ny = min(minY, other.minY)
        let nw = max(maxX, other.maxX) - nx
        let nh = max(maxY, other.maxY) - ny
        return Rect2D(x: nx, y: ny, width: nw, height: nh)
    }

    // MARK: - Insets & Transformations

    @inlinable
    public func insetBy(dx: Double, dy: Double) -> Rect2D {
        Rect2D(
            x: origin.x + dx,
            y: origin.y + dy,
            width: Swift.max(0, size.width - 2 * dx),
            height: Swift.max(0, size.height - 2 * dy)
        )
    }

    @inlinable
    public func expandedBy(dx: Double, dy: Double) -> Rect2D {
        insetBy(dx: -dx, dy: -dy)
    }

    @inlinable
    public func offsetBy(dx: Double, dy: Double) -> Rect2D {
        Rect2D(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
    }

    @inlinable
    public func insetBy(insets: EdgeInsets2D) -> Rect2D {
        Rect2D(
            x: origin.x + insets.left,
            y: origin.y + insets.top,
            width: Swift.max(0, size.width - insets.left - insets.right),
            height: Swift.max(0, size.height - insets.top - insets.bottom)
        )
    }

    @inlinable
    public var isEmpty: Bool {
        size.width <= 1e-9 || size.height <= 1e-9
    }

    public func isApproximatelyEqual(to other: Rect2D, tolerance: Double = 1e-9) -> Bool {
        origin.isApproximatelyEqual(to: other.origin, tolerance: tolerance) &&
        size.isApproximatelyEqual(to: other.size, tolerance: tolerance)
    }

    public var description: String {
        "Rect2D(x: \(String(format: "%.2f", origin.x)), y: \(String(format: "%.2f", origin.y)), w: \(String(format: "%.2f", size.width)), h: \(String(format: "%.2f", size.height)))"
    }

    #if canImport(CoreGraphics)
    @inlinable
    public init(_ cgRect: CGRect) {
        self.init(
            x: Double(cgRect.origin.x),
            y: Double(cgRect.origin.y),
            width: Double(cgRect.size.width),
            height: Double(cgRect.size.height)
        )
    }

    @inlinable
    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    #endif
}

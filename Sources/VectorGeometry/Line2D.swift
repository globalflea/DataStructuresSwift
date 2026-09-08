// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// A finite 2D line segment connecting two endpoints.
public struct Line2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var start: Point2D
    public var end: Point2D

    public static let zero = Line2D(start: .zero, end: .zero)

    @inlinable
    public init(start: Point2D, end: Point2D) {
        self.start = start
        self.end = end
    }

    @inlinable
    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.start = Point2D(x: x1, y: y1)
        self.end = Point2D(x: x2, y: y2)
    }

    @inlinable
    public init(_ start: Point2D, _ end: Point2D) {
        self.start = start
        self.end = end
    }

    @inlinable public var dx: Double { end.x - start.x }
    @inlinable public var dy: Double { end.y - start.y }

    @inlinable
    public var vector: Vector2D {
        end - start
    }

    @inlinable
    public var length: Double {
        start.distance(to: end)
    }

    @inlinable
    public var lengthSquared: Double {
        start.distanceSquared(to: end)
    }

    @inlinable
    public var squaredLength: Double {
        lengthSquared
    }

    @inlinable
    public var angle: Double {
        atan2(dy, dx)
    }

    @inlinable
    public var bearing: Double {
        vector.theta
    }

    @inlinable
    public var midpoint: Point2D {
        Point2D(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)
    }

    /// Unit direction vector from `start` to `end`.
    @inlinable
    public var unitVector: Vector2D {
        let len = length
        guard len > 1e-9 else { return .zero }
        return Vector2D(x: dx / len, y: dy / len)
    }

    /// Unit normal vector perpendicular to the line segment.
    @inlinable
    public var normal: Vector2D {
        let u = unitVector
        return Vector2D(x: -u.y, y: u.x)
    }

    /// Evaluates the point along the line at normalized parameter `t` in [0, 1].
    @inlinable
    public func point(at t: Double) -> Point2D {
        start.lerp(to: end, t: t)
    }

    /// Projects a point onto the infinite line containing this segment, returning parameter `t`.
    @inlinable
    public func projectionParameter(for point: Point2D) -> Double {
        let l2 = lengthSquared
        guard l2 > 1e-9 else { return 0 }
        return ((point.x - start.x) * dx + (point.y - start.y) * dy) / l2
    }

    /// Finds the closest point on this finite line segment to a given target point.
    public func closestPoint(to point: Point2D) -> Point2D {
        let t = projectionParameter(for: point)
        let clampedT = max(0.0, min(1.0, t))
        return self.point(at: clampedT)
    }

    /// Computes the perpendicular or endpoint Euclidean distance from a point to this segment.
    public func distance(to point: Point2D) -> Double {
        closestPoint(to: point).distance(to: point)
    }

    /// Computes the intersection point with another line or segment, or `nil` if parallel or non-intersecting.
    public func intersection(with other: Line2D, isSegment: Bool = true) -> Point2D? {
        let d = dx * other.dy - dy * other.dx
        guard abs(d) > 1e-9 else { return nil }

        let qpX = other.start.x - start.x
        let qpY = other.start.y - start.y

        let t = (qpX * other.dy - qpY * other.dx) / d
        let u = (qpX * dy - qpY * dx) / d

        if isSegment {
            guard t >= -1e-9 && t <= 1.0 + 1e-9 && u >= -1e-9 && u <= 1.0 + 1e-9 else {
                return nil
            }
            return point(at: max(0.0, min(1.0, t)))
        }
        return point(at: t)
    }

    /// Checks whether this line segment intersects another line segment.
    public func intersects(_ other: Line2D) -> Bool {
        intersection(with: other) != nil
    }

    /// Computes all intersection points between this line segment and an axis-aligned rectangle's borders.
    public func intersects(rect: Rect2D) -> [Point2D] {
        let edges = [
            Line2D(start: rect.topLeft, end: rect.topRight),
            Line2D(start: rect.topRight, end: rect.bottomRight),
            Line2D(start: rect.bottomRight, end: rect.bottomLeft),
            Line2D(start: rect.bottomLeft, end: rect.topLeft)
        ]
        var hits: [Point2D] = []
        for edge in edges {
            if let hit = intersection(with: edge) {
                if !hits.contains(where: { $0.distance(to: hit) < 1e-6 }) {
                    hits.append(hit)
                }
            }
        }
        return hits
    }

    public func intersections(with rect: Rect2D) -> [Point2D] {
        intersects(rect: rect)
    }

    public func isApproximatelyEqual(to other: Line2D, tolerance: Double = 1e-9) -> Bool {
        start.isApproximatelyEqual(to: other.start, tolerance: tolerance) &&
        end.isApproximatelyEqual(to: other.end, tolerance: tolerance)
    }

    /// Axis-aligned bounding box encompassing both endpoints.
    @inlinable
    public var boundingBox: Rect2D {
        Rect2D(p1: start, p2: end)
    }

    public var description: String {
        "Line2D(\(start) -> \(end))"
    }
}

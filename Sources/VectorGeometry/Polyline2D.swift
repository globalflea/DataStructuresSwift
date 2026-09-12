// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// An open 2D path composed of contiguous linear segments.
public struct Polyline2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var points: [Point2D]

    @inlinable
    public init(points: [Point2D]) {
        self.points = points
    }

    @inlinable public var count: Int { points.count }
    @inlinable public var pointCount: Int { points.count }
    @inlinable public var isEmpty: Bool { points.isEmpty }

    /// Consecutive line segments forming the polyline.
    public var segments: [Line2D] {
        guard points.count >= 2 else { return [] }
        var result: [Line2D] = []
        for i in 0..<(points.count - 1) {
            result.append(Line2D(start: points[i], end: points[i + 1]))
        }
        return result
    }

    /// Total cumulative arc-length of the polyline.
    public var length: Double {
        segments.reduce(0.0) { $0 + $1.length }
    }

    @inlinable public var totalLength: Double { length }

    /// Axis-aligned bounding box tightly enclosing all vertices.
    public var boundingBox: Rect2D {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y

        for p in points.dropFirst() {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        return Rect2D(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Evaluates the point along the polyline at normalized progress `t` in [0, 1].
    public func point(at t: Double) -> Point2D {
        guard !points.isEmpty else { return .zero }
        guard points.count > 1 else { return points[0] }
        let clampedT = max(0.0, min(1.0, t))
        let totalLen = length
        guard totalLen > 1e-9 else { return points[0] }

        let targetDist = clampedT * totalLen
        var accumulated = 0.0

        for seg in segments {
            let segLen = seg.length
            if accumulated + segLen >= targetDist || seg == segments.last {
                let remaining = targetDist - accumulated
                let localT = segLen > 1e-9 ? remaining / segLen : 0.0
                return seg.point(at: max(0.0, min(1.0, localT)))
            }
            accumulated += segLen
        }
        return points.last!
    }

    /// Finds the closest point on any segment of the polyline to the given point.
    public func closestPoint(to point: Point2D) -> Point2D {
        guard !points.isEmpty else { return .zero }
        guard points.count > 1 else { return points[0] }

        var bestPoint = points[0]
        var bestDist = Double.infinity

        for seg in segments {
            let cp = seg.closestPoint(to: point)
            let d = cp.distance(to: point)
            if d < bestDist {
                bestDist = d
                bestPoint = cp
            }
        }
        return bestPoint
    }

    /// Computes the shortest distance from the given point to this polyline.
    @inlinable
    public func distance(to point: Point2D) -> Double {
        guard !points.isEmpty else { return .infinity }
        guard points.count >= 2 else { return points[0].distance(to: point) }
        return closestPoint(to: point).distance(to: point)
    }

    /// Tests whether a point lies within `tolerance` distance of the polyline.
    @inlinable
    public func contains(point: Point2D, tolerance: Double = 5.0) -> Bool {
        distance(to: point) <= tolerance
    }

    /// Returns the point located at a fractional distance `fraction` along the polyline (0.0 to 1.0).
    @inlinable
    public func point(atFraction fraction: Double) -> Point2D {
        point(at: fraction)
    }

    /// Simplifies the polyline using the Ramer-Douglas-Peucker algorithm.
    public func simplified(tolerance: Double) -> Polyline2D {
        guard points.count > 2 else { return self }
        let kept = rdpRecursive(points: points, tolerance: tolerance)
        return Polyline2D(points: kept)
    }

    private func rdpRecursive(points: [Point2D], tolerance: Double) -> [Point2D] {
        guard points.count > 2 else { return points }

        let line = Line2D(start: points.first!, end: points.last!)
        var maxDist = 0.0
        var index = 0

        for i in 1..<(points.count - 1) {
            let d = line.distance(to: points[i])
            if d > maxDist {
                maxDist = d
                index = i
            }
        }

        if maxDist > tolerance {
            let left = rdpRecursive(points: Array(points[0...index]), tolerance: tolerance)
            let right = rdpRecursive(points: Array(points[index..<points.count]), tolerance: tolerance)
            return left.dropLast() + right
        } else {
            return [points.first!, points.last!]
        }
    }

    public var description: String {
        "Polyline2D(\(points.count) vertices, len: \(String(format: "%.2f", length)))"
    }
}

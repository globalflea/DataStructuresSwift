// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// A 2D ellipse defined by its center point and radii along the X and Y axes.
public struct Ellipse2D: Hashable, Equatable, Sendable, Codable, CustomStringConvertible {
    public var center: Point2D
    public var radiusX: Double
    public var radiusY: Double

    public static let zero = Ellipse2D(center: .zero, radiusX: 0, radiusY: 0)

    @inlinable
    public init(center: Point2D, radiusX: Double, radiusY: Double) {
        self.center = center
        self.radiusX = max(0, radiusX)
        self.radiusY = max(0, radiusY)
    }

    @inlinable
    public init(center: Point2D, radius: Double) {
        self.init(center: center, radiusX: radius, radiusY: radius)
    }

    /// Total surface area (π * a * b).
    @inlinable
    public var area: Double {
        .pi * radiusX * radiusY
    }

    /// Circumference approximation using Ramanujan's formula.
    public var circumference: Double {
        let a = radiusX
        let b = radiusY
        let h = ((a - b) * (a - b)) / ((a + b) * (a + b))
        return .pi * (a + b) * (1 + (3 * h) / (10 + (4 - 3 * h).squareRoot()))
    }

    /// Checks whether the point is inside or on the ellipse boundary.
    public func contains(_ point: Point2D) -> Bool {
        guard radiusX > 1e-9 && radiusY > 1e-9 else { return false }
        let dx = (point.x - center.x) / radiusX
        let dy = (point.y - center.y) / radiusY
        return (dx * dx + dy * dy) <= 1.0 + 1e-9
    }

    /// Computes a point on the perimeter of the ellipse at a given angle in radians.
    public func point(atAngle radians: Double) -> Point2D {
        Point2D(x: center.x + radiusX * cos(radians), y: center.y + radiusY * sin(radians))
    }

    /// Smallest axis-aligned bounding box enclosing this ellipse.
    public var boundingBox: Rect2D {
        Rect2D(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2)
    }

    /// Intersects a ray from the ellipse center to an external point, returning the boundary point.
    public func intersectionWithRay(to target: Point2D) -> Point2D? {
        let angle = (target - center).theta
        return point(atAngle: angle)
    }

    /// Epsilon-tolerant comparison.
    public func isApproximatelyEqual(to other: Ellipse2D, tolerance: Double = 1e-9) -> Bool {
        center.isApproximatelyEqual(to: other.center, tolerance: tolerance) &&
        abs(radiusX - other.radiusX) <= tolerance &&
        abs(radiusY - other.radiusY) <= tolerance
    }

    public var description: String {
        "Ellipse2D(center: \(center), rx: \(String(format: "%.2f", radiusX)), ry: \(String(format: "%.2f", radiusY)))"
    }
}

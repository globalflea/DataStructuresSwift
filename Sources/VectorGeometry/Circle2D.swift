// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// A 2D circle specified by center coordinates and radius.
public struct Circle2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var center: Point2D
    public var radius: Double

    public static let zero = Circle2D(center: .zero, radius: 0)

    @inlinable
    public init(center: Point2D, radius: Double) {
        self.center = center
        self.radius = max(0, radius)
    }

    @inlinable
    public init(x: Double, y: Double, radius: Double) {
        self.init(center: Point2D(x: x, y: y), radius: radius)
    }

    @inlinable public var diameter: Double { radius * 2 }
    @inlinable public var area: Double { .pi * radius * radius }
    @inlinable public var circumference: Double { 2 * .pi * radius }

    @inlinable
    public var boundingBox: Rect2D {
        Rect2D(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }

    @inlinable
    public func contains(_ point: Point2D) -> Bool {
        center.distanceSquared(to: point) <= (radius * radius) + 1e-9
    }

    @inlinable
    public func contains(point: Point2D) -> Bool {
        contains(point)
    }

    @inlinable
    public func intersects(circle: Circle2D) -> Bool {
        let maxR = radius + circle.radius
        return center.distanceSquared(to: circle.center) <= (maxR * maxR) + 1e-9
    }

    public func intersects(rect: Rect2D) -> Bool {
        let closestX = Swift.max(rect.minX, Swift.min(center.x, rect.maxX))
        let closestY = Swift.max(rect.minY, Swift.min(center.y, rect.maxY))
        let closestPoint = Point2D(x: closestX, y: closestY)
        return contains(closestPoint)
    }

    /// Computes real intersection points with a line segment.
    public func intersectionPoints(with line: Line2D) -> [Point2D] {
        let d = line.unitVector
        let f = line.start - center
        let a = d.dot(d)
        let b = 2.0 * f.dot(Vector2D(x: d.x, y: d.y))
        let c = f.magnitudeSquared - radius * radius

        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return [] }

        let sqrtDisc = discriminant.squareRoot()
        let t1 = (-b - sqrtDisc) / (2 * a)
        let t2 = (-b + sqrtDisc) / (2 * a)

        var points: [Point2D] = []
        let len = line.length
        if t1 >= -1e-9 && t1 <= len + 1e-9 {
            points.append(line.point(at: len > 0 ? t1 / len : 0))
        }
        if discriminant > 1e-9 && t2 >= -1e-9 && t2 <= len + 1e-9 {
            points.append(line.point(at: len > 0 ? t2 / len : 0))
        }
        return points
    }

    public var description: String {
        "Circle2D(center: \(center), radius: \(radius))"
    }
}

/// A 2D circular arc defined by center, radius, start angle, and end angle.
public struct Arc2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var center: Point2D
    public var radius: Double
    public var startAngle: Double
    public var endAngle: Double
    public var isClockwise: Bool

    public init(
        center: Point2D = .zero,
        radius: Double,
        startAngle: Double,
        endAngle: Double,
        isClockwise: Bool = false
    ) {
        self.center = center
        self.radius = Swift.max(0, radius)
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.isClockwise = isClockwise
    }

    @inlinable
    public var startPoint: Point2D {
        Point2D(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
    }

    @inlinable
    public var endPoint: Point2D {
        Point2D(x: center.x + radius * cos(endAngle), y: center.y + radius * sin(endAngle))
    }

    @inlinable
    public var sweepAngle: Double {
        var diff = endAngle - startAngle
        if isClockwise {
            if diff > 0 { diff -= 2.0 * .pi }
        } else {
            if diff < 0 { diff += 2.0 * .pi }
        }
        return abs(diff)
    }

    @inlinable
    public var arcLength: Double {
        radius * sweepAngle
    }

    public var description: String {
        "Arc2D(center: \(center), r: \(radius), start: \(startAngle), end: \(endAngle))"
    }
}

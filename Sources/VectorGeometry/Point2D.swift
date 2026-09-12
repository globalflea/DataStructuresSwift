// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A point in 2D Cartesian coordinate space represented by 64-bit floating point coordinates.
public struct Point2D: Sendable, Hashable, Equatable, Codable, Comparable, CustomStringConvertible {
    public var x: Double
    public var y: Double

    public static let zero = Point2D(x: 0, y: 0)

    @inlinable
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    @inlinable
    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    // MARK: - Point & Vector Arithmetic

    @inlinable
    public static func + (lhs: Point2D, rhs: Point2D) -> Point2D {
        Point2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    @inlinable
    public static func - (lhs: Point2D, rhs: Point2D) -> Vector2D {
        Vector2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    @inlinable
    public static func + (point: Point2D, vector: Vector2D) -> Point2D {
        Point2D(x: point.x + vector.x, y: point.y + vector.y)
    }

    @inlinable
    public static func - (point: Point2D, vector: Vector2D) -> Point2D {
        Point2D(x: point.x - vector.x, y: point.y - vector.y)
    }

    @inlinable
    public static func * (point: Point2D, scalar: Double) -> Point2D {
        Point2D(x: point.x * scalar, y: point.y * scalar)
    }

    @inlinable
    public static func * (scalar: Double, point: Point2D) -> Point2D {
        point * scalar
    }

    @inlinable
    public static func / (point: Point2D, scalar: Double) -> Point2D {
        precondition(scalar != 0, "Division by zero in Point2D.")
        return Point2D(x: point.x / scalar, y: point.y / scalar)
    }

    @inlinable
    public static prefix func - (point: Point2D) -> Point2D {
        Point2D(x: -point.x, y: -point.y)
    }

    @inlinable
    public static func += (lhs: inout Point2D, rhs: Point2D) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    @inlinable
    public static func += (lhs: inout Point2D, rhs: Vector2D) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    @inlinable
    public static func -= (lhs: inout Point2D, rhs: Point2D) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }

    @inlinable
    public static func -= (lhs: inout Point2D, rhs: Vector2D) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }

    // MARK: - Comparable

    @inlinable
    public static func < (lhs: Point2D, rhs: Point2D) -> Bool {
        if lhs.x == rhs.x {
            return lhs.y < rhs.y
        }
        return lhs.x < rhs.x
    }

    // MARK: - Metrics & Vector Math

    /// Euclidean length (magnitude) from the origin.
    @inlinable
    public var magnitude: Double {
        (x * x + y * y).squareRoot()
    }

    /// Squared Euclidean magnitude, avoiding square root calculation.
    @inlinable
    public var squaredMagnitude: Double {
        x * x + y * y
    }

    /// Dot product treating this point as a vector from the origin.
    @inlinable
    public func dot(_ other: Point2D) -> Double {
        x * other.x + y * other.y
    }

    /// 2D cross product (perp-dot product): `x1 * y2 - y1 * x2`.
    @inlinable
    public func cross(_ other: Point2D) -> Double {
        x * other.y - y * other.x
    }

    /// Unit vector pointing in the same direction, or `.zero` if magnitude is near zero.
    public func normalized() -> Point2D {
        let mag = magnitude
        guard mag > 1e-9 else { return .zero }
        return Point2D(x: x / mag, y: y / mag)
    }

    /// Euclidean distance to another point.
    @inlinable
    public func distance(to other: Point2D) -> Double {
        (self - other).magnitude
    }

    /// Squared Euclidean distance to another point.
    @inlinable
    public func distanceSquared(to other: Point2D) -> Double {
        (self - other).magnitudeSquared
    }

    /// Compatibility alias for distanceSquared.
    @inlinable
    public func squaredDistance(to other: Point2D) -> Double {
        distanceSquared(to: other)
    }

    /// Angle in radians relative to positive X-axis (-π to π).
    @inlinable
    public var theta: Double {
        atan2(y, x)
    }

    /// Angle in radians from this point to another point relative to origin.
    public func angle(to other: Point2D) -> Double {
        atan2(cross(other), dot(other))
    }

    /// Rotates the point counter-clockwise by `radians` around a pivot point.
    public func rotated(byAngle radians: Double, around pivot: Point2D = .zero) -> Point2D {
        let cosA = cos(radians)
        let sinA = sin(radians)
        let dx = x - pivot.x
        let dy = y - pivot.y
        let rx = dx * cosA - dy * sinA + pivot.x
        let ry = dx * sinA + dy * cosA + pivot.y
        return Point2D(x: rx, y: ry)
    }

    /// Linear interpolation between this point and target point at parameter `t` in [0, 1].
    @inlinable
    public func lerp(to target: Point2D, t: Double) -> Point2D {
        Point2D(
            x: x + (target.x - x) * t,
            y: y + (target.y - y) * t
        )
    }

    /// Epsilon-tolerant equality comparison.
    public func isApproximatelyEqual(to other: Point2D, tolerance: Double = 1e-9) -> Bool {
        abs(x - other.x) <= tolerance && abs(y - other.y) <= tolerance
    }

    @inlinable
    public init(_ vector: Vector2D) {
        self.x = vector.x
        self.y = vector.y
    }

    @inlinable
    public var asVector: Vector2D {
        Vector2D(x: x, y: y)
    }

    public var description: String {
        "Point2D(\(String(format: "%.3f", x)), \(String(format: "%.3f", y)))"
    }

    #if canImport(CoreGraphics)
    @inlinable
    public init(_ cgPoint: CGPoint) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
    }

    @inlinable
    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
    #endif
}

extension Double {
    @inlinable
    public func isApproximatelyEqual(to other: Double, tolerance: Double = 1e-9) -> Bool {
        abs(self - other) <= tolerance
    }
}


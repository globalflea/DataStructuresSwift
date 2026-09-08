// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// A 2D geometric vector representing direction and magnitude in 2D Cartesian space.
public struct Vector2D: Sendable, Hashable, Equatable, Codable, AdditiveArithmetic, CustomStringConvertible {
    public var x: Double
    public var y: Double

    @inlinable
    public static var zero: Vector2D {
        Vector2D(x: 0, y: 0)
    }

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

    @inlinable
    public static func + (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    @inlinable
    public static func - (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    @inlinable
    public static prefix func - (v: Vector2D) -> Vector2D {
        Vector2D(x: -v.x, y: -v.y)
    }

    @inlinable
    public static func * (lhs: Vector2D, rhs: Double) -> Vector2D {
        Vector2D(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    @inlinable
    public static func * (lhs: Double, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs * rhs.x, y: lhs * rhs.y)
    }

    @inlinable
    public static func / (lhs: Vector2D, rhs: Double) -> Vector2D {
        precondition(rhs != 0, "Division by zero in Vector2D")
        return Vector2D(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    @inlinable
    public static func += (lhs: inout Vector2D, rhs: Vector2D) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }

    @inlinable
    public static func -= (lhs: inout Vector2D, rhs: Vector2D) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }

    /// Computes the dot product of two vectors: `x1 * x2 + y1 * y2`.
    @inlinable
    public func dot(_ other: Vector2D) -> Double {
        x * other.x + y * other.y
    }

    /// Computes the 2D cross product (perp-dot product): `x1 * y2 - y1 * x2`.
    @inlinable
    public func cross(_ other: Vector2D) -> Double {
        x * other.y - y * other.x
    }

    /// The Euclidean magnitude (length) of the vector.
    @inlinable
    public var magnitude: Double {
        (x * x + y * y).squareRoot()
    }

    /// The squared Euclidean magnitude (avoids square root for performance comparisons).
    @inlinable
    public var magnitudeSquared: Double {
        x * x + y * y
    }

    /// Returns a normalized unit vector with magnitude 1.0, or `.zero` if length is 0.
    @inlinable
    public func normalized() -> Vector2D {
        let mag = magnitude
        return mag > 1e-9 ? self / mag : .zero
    }

    /// Computes the distance to another vector.
    @inlinable
    public func distance(to other: Vector2D) -> Double {
        (self - other).magnitude
    }

    /// Computes the squared distance to another vector.
    @inlinable
    public func distanceSquared(to other: Vector2D) -> Double {
        (self - other).magnitudeSquared
    }

    /// The angle of the vector in radians relative to the positive X-axis (-π to π).
    @inlinable
    public var angle: Double {
        atan2(y, x)
    }

    /// Returns the vector rotated by `radians` counter-clockwise.
    @inlinable
    public func rotated(by radians: Double) -> Vector2D {
        let cosA = cos(radians)
        let sinA = sin(radians)
        return Vector2D(x: x * cosA - y * sinA, y: x * sinA + y * cosA)
    }

    /// Linearly interpolates between this vector and `target` with factor `t` in [0, 1].
    @inlinable
    public func lerp(to target: Vector2D, t: Double) -> Vector2D {
        self + (target - self) * t
    }

    /// Epsilon-tolerant comparison.
    public func isApproximatelyEqual(to other: Vector2D, tolerance: Double = 1e-9) -> Bool {
        abs(x - other.x) <= tolerance && abs(y - other.y) <= tolerance
    }

    public var description: String {
        "Vector2D(\(String(format: "%.3f", x)), \(String(format: "%.3f", y)))"
    }
}

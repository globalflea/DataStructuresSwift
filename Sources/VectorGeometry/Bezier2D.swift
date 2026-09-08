// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// A 2D quadratic Bézier curve defined by 3 control points (start, control, end).
public struct QuadraticBezier2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var p0: Point2D
    public var p1: Point2D
    public var p2: Point2D

    public static let zero = QuadraticBezier2D(p0: .zero, p1: .zero, p2: .zero)

    @inlinable
    public init(p0: Point2D, p1: Point2D, p2: Point2D) {
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
    }

    /// Evaluates the curve position at normalized progress $t \in [0, 1]$.
    @inlinable
    public func point(at t: Double) -> Point2D {
        let u = 1.0 - t
        let tt = t * t
        let uu = u * u
        let ut2 = 2.0 * u * t

        return Point2D(
            x: uu * p0.x + ut2 * p1.x + tt * p2.x,
            y: uu * p0.y + ut2 * p1.y + tt * p2.y
        )
    }

    /// Computes the first derivative (velocity vector) $B'(t)$.
    @inlinable
    public func derivative(at t: Double) -> Vector2D {
        let u = 1.0 - t
        return Vector2D(
            x: 2.0 * (u * (p1.x - p0.x) + t * (p2.x - p1.x)),
            y: 2.0 * (u * (p1.y - p0.y) + t * (p2.y - p1.y))
        )
    }

    /// Subdivides the quadratic Bézier into two curves at parameter $t$ via de Casteljau's algorithm.
    public func split(at t: Double) -> (left: QuadraticBezier2D, right: QuadraticBezier2D) {
        let q0 = p0.lerp(to: p1, t: t)
        let q1 = p1.lerp(to: p2, t: t)
        let r = q0.lerp(to: q1, t: t)

        let left = QuadraticBezier2D(p0: p0, p1: q0, p2: r)
        let right = QuadraticBezier2D(p0: r, p1: q1, p2: p2)
        return (left, right)
    }

    /// Approximates the arc-length via numerical Gauss-Legendre or Simpson's quadrature.
    public func arcLength(samples: Int = 16) -> Double {
        let n = max(4, samples)
        var len = 0.0
        var prev = p0
        for i in 1...n {
            let t = Double(i) / Double(n)
            let curr = point(at: t)
            len += prev.distance(to: curr)
            prev = curr
        }
        return len
    }

    /// Exact axis-aligned bounding box incorporating curve extrema.
    public var boundingBox: Rect2D {
        var minX = min(p0.x, p2.x)
        var maxX = max(p0.x, p2.x)
        var minY = min(p0.y, p2.y)
        var maxY = max(p0.y, p2.y)

        let denomX = p0.x - 2.0 * p1.x + p2.x
        if abs(denomX) > 1e-9 {
            let tx = (p0.x - p1.x) / denomX
            if tx > 0.0 && tx < 1.0 {
                let x = point(at: tx).x
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }

        let denomY = p0.y - 2.0 * p1.y + p2.y
        if abs(denomY) > 1e-9 {
            let ty = (p0.y - p1.y) / denomY
            if ty > 0.0 && ty < 1.0 {
                let y = point(at: ty).y
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }

        return Rect2D(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Degree elevation from quadratic to cubic Bézier without altering the curve's geometry.
    public func elevateToCubic() -> CubicBezier2D {
        let cp1 = Point2D(
            x: p0.x + (2.0 / 3.0) * (p1.x - p0.x),
            y: p0.y + (2.0 / 3.0) * (p1.y - p0.y)
        )
        let cp2 = Point2D(
            x: p2.x + (2.0 / 3.0) * (p1.x - p2.x),
            y: p2.y + (2.0 / 3.0) * (p1.y - p2.y)
        )
        return CubicBezier2D(p0: p0, p1: cp1, p2: cp2, p3: p2)
    }

    public var description: String {
        "QuadraticBezier2D(\(p0) -> \(p1) -> \(p2))"
    }
}

/// A 2D cubic Bézier curve defined by 4 control points (start, cp1, cp2, end).
public struct CubicBezier2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var p0: Point2D
    public var p1: Point2D
    public var p2: Point2D
    public var p3: Point2D

    public static let zero = CubicBezier2D(p0: .zero, p1: .zero, p2: .zero, p3: .zero)

    @inlinable
    public init(p0: Point2D, p1: Point2D, p2: Point2D, p3: Point2D) {
        self.p0 = p0
        self.p1 = p1
        self.p2 = p2
        self.p3 = p3
    }

    /// Evaluates the curve position at normalized progress $t \in [0, 1]$.
    @inlinable
    public func point(at t: Double) -> Point2D {
        let u = 1.0 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t

        let c1 = 3.0 * uu * t
        let c2 = 3.0 * u * tt

        return Point2D(
            x: uuu * p0.x + c1 * p1.x + c2 * p2.x + ttt * p3.x,
            y: uuu * p0.y + c1 * p1.y + c2 * p2.y + ttt * p3.y
        )
    }

    /// Computes the first derivative vector $B'(t)$.
    @inlinable
    public func derivative(at t: Double) -> Vector2D {
        let u = 1.0 - t
        let c0 = 3.0 * u * u
        let c1 = 6.0 * u * t
        let c2 = 3.0 * t * t

        return Vector2D(
            x: c0 * (p1.x - p0.x) + c1 * (p2.x - p1.x) + c2 * (p3.x - p2.x),
            y: c0 * (p1.y - p0.y) + c1 * (p2.y - p1.y) + c2 * (p3.y - p2.y)
        )
    }

    /// Normalized unit tangent vector at parameter $t$.
    @inlinable
    public func tangent(at t: Double) -> Vector2D {
        derivative(at: t).normalized()
    }

    /// Normalized unit normal vector perpendicular to tangent at parameter $t$.
    @inlinable
    public func normal(at t: Double) -> Vector2D {
        let tan = tangent(at: t)
        return Vector2D(x: -tan.y, y: tan.x)
    }

    /// Subdivides the cubic Bézier into two curves at parameter $t$ via de Casteljau's algorithm.
    public func split(at t: Double) -> (left: CubicBezier2D, right: CubicBezier2D) {
        let q0 = p0.lerp(to: p1, t: t)
        let q1 = p1.lerp(to: p2, t: t)
        let q2 = p2.lerp(to: p3, t: t)

        let r0 = q0.lerp(to: q1, t: t)
        let r1 = q1.lerp(to: q2, t: t)

        let s = r0.lerp(to: r1, t: t)

        let left = CubicBezier2D(p0: p0, p1: q0, p2: r0, p3: s)
        let right = CubicBezier2D(p0: s, p1: r1, p2: q2, p3: p3)
        return (left, right)
    }

    /// Approximates the arc-length via numerical integration.
    public func arcLength(samples: Int = 24) -> Double {
        let n = max(4, samples)
        var len = 0.0
        var prev = p0
        for i in 1...n {
            let t = Double(i) / Double(n)
            let curr = point(at: t)
            len += prev.distance(to: curr)
            prev = curr
        }
        return len
    }

    /// Returns roots in (0, 1) of the derivative for an axis, yielding local extrema.
    private func derivativeRoots(p0: Double, p1: Double, p2: Double, p3: Double) -> [Double] {
        let a = 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3)
        let b = 6.0 * (p0 - 2.0 * p1 + p2)
        let c = 3.0 * (p1 - p0)

        if abs(a) < 1e-9 {
            if abs(b) > 1e-9 {
                let t = -c / b
                if t > 0.0 && t < 1.0 { return [t] }
            }
            return []
        }

        let disc = b * b - 4.0 * a * c
        guard disc >= 0.0 else { return [] }

        let sqrtDisc = disc.squareRoot()
        var roots: [Double] = []
        let t1 = (-b - sqrtDisc) / (2.0 * a)
        let t2 = (-b + sqrtDisc) / (2.0 * a)

        if t1 > 0.0 && t1 < 1.0 { roots.append(t1) }
        if t2 > 0.0 && t2 < 1.0 && abs(t2 - t1) > 1e-6 { roots.append(t2) }
        return roots
    }

    /// Exact axis-aligned bounding box including endpoints and derivative extrema.
    public var boundingBox: Rect2D {
        var minX = min(p0.x, p3.x)
        var maxX = max(p0.x, p3.x)
        var minY = min(p0.y, p3.y)
        var maxY = max(p0.y, p3.y)

        for tx in derivativeRoots(p0: p0.x, p1: p1.x, p2: p2.x, p3: p3.x) {
            let x = point(at: tx).x
            minX = min(minX, x)
            maxX = max(maxX, x)
        }

        for ty in derivativeRoots(p0: p0.y, p1: p1.y, p2: p2.y, p3: p3.y) {
            let y = point(at: ty).y
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        return Rect2D(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Finds closest parameter $t \in [0, 1]$ to a given point via sampling and Newton-Raphson refinement.
    public func closestParameter(to target: Point2D, samples: Int = 20) -> Double {
        var bestT = 0.0
        var bestDistSq = Double.infinity

        for i in 0...samples {
            let t = Double(i) / Double(samples)
            let p = point(at: t)
            let dSq = p.distanceSquared(to: target)
            if dSq < bestDistSq {
                bestDistSq = dSq
                bestT = t
            }
        }

        // Newton-Raphson refinement
        var t = bestT
        for _ in 0..<5 {
            let p = point(at: t)
            let d = derivative(at: t)
            let diff = p - target
            let num = diff.x * d.x + diff.y * d.y
            let denom = d.magnitudeSquared
            guard abs(denom) > 1e-9 else { break }
            t = max(0.0, min(1.0, t - num / denom))
        }

        return t
    }

    /// Closest point on the cubic Bézier curve to the target.
    public func closestPoint(to target: Point2D, samples: Int = 20) -> Point2D {
        point(at: closestParameter(to: target, samples: samples))
    }

    public var description: String {
        "CubicBezier2D(\(p0) -> \(p1) -> \(p2) -> \(p3))"
    }
}

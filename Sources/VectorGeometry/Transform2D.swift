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

/// A 3x3 affine transformation matrix for 2D graphics:
/// ```
/// [ a   c   tx ]
/// [ b   d   ty ]
/// [ 0   0   1  ]
/// ```
public struct Transform2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var a: Double
    public var b: Double
    public var c: Double
    public var d: Double
    public var tx: Double
    public var ty: Double

    public static let identity = Transform2D(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    @inlinable
    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    @inlinable
    public static func translation(x: Double, y: Double) -> Transform2D {
        Transform2D(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y)
    }

    @inlinable
    public static func scale(x: Double, y: Double) -> Transform2D {
        Transform2D(a: x, b: 0, c: 0, d: y, tx: 0, ty: 0)
    }

    @inlinable
    public static func scale(_ s: Double) -> Transform2D {
        scale(x: s, y: s)
    }

    @inlinable
    public static func rotation(radians: Double) -> Transform2D {
        let cosA = cos(radians)
        let sinA = sin(radians)
        return Transform2D(a: cosA, b: sinA, c: -sinA, d: cosA, tx: 0, ty: 0)
    }

    @inlinable
    public static func translation(dx: Double, dy: Double) -> Transform2D {
        Transform2D(a: 1, b: 0, c: 0, d: 1, tx: dx, ty: dy)
    }

    @inlinable
    public static func translation(_ vector: Vector2D) -> Transform2D {
        translation(x: vector.x, y: vector.y)
    }

    @inlinable
    public static func translation(_ offset: Point2D) -> Transform2D {
        translation(x: offset.x, y: offset.y)
    }

    @inlinable
    public static func scale(sx: Double, sy: Double) -> Transform2D {
        scale(x: sx, y: sy)
    }

    @inlinable
    public static func scale(sx: Double, sy: Double, around pivot: Point2D) -> Transform2D {
        translation(x: -pivot.x, y: -pivot.y)
            .concatenating(.scale(x: sx, y: sy))
            .concatenating(.translation(x: pivot.x, y: pivot.y))
    }

    @inlinable
    public static func rotation(radians: Double, around pivot: Point2D) -> Transform2D {
        translation(x: -pivot.x, y: -pivot.y)
            .concatenating(.rotation(radians: radians))
            .concatenating(.translation(x: pivot.x, y: pivot.y))
    }

    @inlinable
    public static func skew(xRadians: Double, yRadians: Double) -> Transform2D {
        Transform2D(a: 1, b: tan(yRadians), c: tan(xRadians), d: 1, tx: 0, ty: 0)
    }

    // MARK: - Concatenation & Arithmetic

    /// Concatenates this transform with `other` (`self * other` in row-vector order, applying self then other).
    @inlinable
    public func concatenating(_ other: Transform2D) -> Transform2D {
        Transform2D(
            a: a * other.a + b * other.c,
            b: a * other.b + b * other.d,
            c: c * other.a + d * other.c,
            d: c * other.b + d * other.d,
            tx: tx * other.a + ty * other.c + other.tx,
            ty: tx * other.b + ty * other.d + other.ty
        )
    }

    @inlinable
    public static func * (lhs: Transform2D, rhs: Transform2D) -> Transform2D {
        rhs.concatenating(lhs)
    }

    // MARK: - Fluently Chained Transforms

    @inlinable
    public func translatedBy(x: Double, y: Double) -> Transform2D {
        concatenating(.translation(x: x, y: y))
    }

    @inlinable
    public func translatedBy(_ delta: Vector2D) -> Transform2D {
        translatedBy(x: delta.x, y: delta.y)
    }

    @inlinable
    public func scaledBy(x: Double, y: Double) -> Transform2D {
        concatenating(.scale(x: x, y: y))
    }

    @inlinable
    public func scaledBy(_ s: Double) -> Transform2D {
        scaledBy(x: s, y: s)
    }

    @inlinable
    public func rotatedBy(radians: Double) -> Transform2D {
        concatenating(.rotation(radians: radians))
    }

    @inlinable
    public func rotated(byAngle radians: Double) -> Transform2D {
        rotatedBy(radians: radians)
    }

    // MARK: - Matrix Inversion

    @inlinable
    public var determinant: Double {
        a * d - b * c
    }

    @inlinable
    public var isInvertible: Bool {
        abs(determinant) > 1e-9
    }

    /// Computes the inverse affine transform, or `nil` if singular (determinant near zero).
    public func inverted() -> Transform2D? {
        let det = determinant
        guard abs(det) > 1e-9 else { return nil }
        let invDet = 1.0 / det

        return Transform2D(
            a: d * invDet,
            b: -b * invDet,
            c: -c * invDet,
            d: a * invDet,
            tx: (c * ty - d * tx) * invDet,
            ty: (b * tx - a * ty) * invDet
        )
    }

    // MARK: - Geometric Application

    @inlinable
    public func apply(to point: Point2D) -> Point2D {
        Point2D(
            x: a * point.x + c * point.y + tx,
            y: b * point.x + d * point.y + ty
        )
    }

    @inlinable
    public func transform(_ point: Point2D) -> Point2D {
        apply(to: point)
    }

    @inlinable
    public func apply(to vector: Vector2D) -> Vector2D {
        Vector2D(
            x: a * vector.x + c * vector.y,
            y: b * vector.x + d * vector.y
        )
    }

    @inlinable
    public func transform(_ vector: Vector2D) -> Vector2D {
        apply(to: vector)
    }

    @inlinable
    public func apply(to line: Line2D) -> Line2D {
        Line2D(start: apply(to: line.start), end: apply(to: line.end))
    }

    @inlinable
    public func apply(to polygon: Polygon2D) -> Polygon2D {
        Polygon2D(vertices: polygon.vertices.map { apply(to: $0) })
    }

    public func apply(to rect: Rect2D) -> Rect2D {
        let p1 = apply(to: rect.topLeft)
        let p2 = apply(to: rect.topRight)
        let p3 = apply(to: rect.bottomLeft)
        let p4 = apply(to: rect.bottomRight)

        let minX = min(p1.x, p2.x, p3.x, p4.x)
        let maxX = max(p1.x, p2.x, p3.x, p4.x)
        let minY = min(p1.y, p2.y, p3.y, p4.y)
        let maxY = max(p1.y, p2.y, p3.y, p4.y)

        return Rect2D(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    @inlinable
    public func transform(_ rect: Rect2D) -> Rect2D {
        apply(to: rect)
    }

    /// Decomposes the transform into its translation, scale, rotation (radians), and skew.
    public func decompose() -> (translation: Vector2D, scale: Vector2D, rotation: Double, skew: Double) {
        let translation = Vector2D(x: tx, y: ty)
        let scaleX = (a * a + b * b).squareRoot()
        var scaleY = (c * c + d * d).squareRoot()
        let det = determinant
        if det < 0 {
            scaleY = -scaleY
        }
        let rotation = atan2(b, a)
        let skew = atan2(a * c + b * d, scaleX * scaleX)
        return (translation, Vector2D(x: scaleX, y: scaleY), rotation, skew)
    }

    public func isApproximatelyEqual(to other: Transform2D, tolerance: Double = 1e-9) -> Bool {
        abs(a - other.a) <= tolerance &&
        abs(b - other.b) <= tolerance &&
        abs(c - other.c) <= tolerance &&
        abs(d - other.d) <= tolerance &&
        abs(tx - other.tx) <= tolerance &&
        abs(ty - other.ty) <= tolerance
    }

    public var description: String {
        let fmtA = String(format: "%.2f", a)
        let fmtC = String(format: "%.2f", c)
        let fmtTx = String(format: "%.2f", tx)
        let fmtB = String(format: "%.2f", b)
        let fmtD = String(format: "%.2f", d)
        let fmtTy = String(format: "%.2f", ty)
        return "Transform2D([\(fmtA), \(fmtC), \(fmtTx)], [\(fmtB), \(fmtD), \(fmtTy)])"
    }

    #if canImport(CoreGraphics)
    @inlinable
    public init(_ cgTransform: CGAffineTransform) {
        self.a = Double(cgTransform.a)
        self.b = Double(cgTransform.b)
        self.c = Double(cgTransform.c)
        self.d = Double(cgTransform.d)
        self.tx = Double(cgTransform.tx)
        self.ty = Double(cgTransform.ty)
    }

    @inlinable
    public var cgTransform: CGAffineTransform {
        CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }

    @inlinable
    public var cgAffineTransform: CGAffineTransform {
        cgTransform
    }
    #endif
}

/// Backwards compatibility alias for JointSwift and existing callers.
public typealias AffineTransform2D = Transform2D

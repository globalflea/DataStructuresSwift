// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Testing
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import VectorGeometry

@Suite("VectorGeometry Foundation Tests")
struct VectorGeometryTests {

    @Test("Point2D and Vector2D operations and metrics")
    func testPointAndVector() {
        let p1 = Point2D(x: 3, y: 4)
        let p2 = Point2D(6, 8)
        let v1 = Vector2D(x: 1, y: 2)
        let v2 = Vector2D(3, 4)

        // Point arithmetic
        #expect(p1.magnitude == 5.0)
        #expect(p1.squaredMagnitude == 25.0)
        #expect(p1 + p2 == Point2D(9, 12))
        #expect(p2 - p1 == Vector2D(3, 4))
        #expect(p1 + v1 == Point2D(4, 6))
        #expect(p1 - v1 == Point2D(2, 2))
        #expect(p1 * 2.0 == Point2D(6, 8))
        #expect(2.0 * p1 == Point2D(6, 8))
        #expect(p2 / 2.0 == Point2D(3, 4))
        #expect(-p1 == Point2D(-3, -4))

        var pMut = Point2D(1, 1)
        pMut += Point2D(2, 2)
        #expect(pMut == Point2D(3, 3))
        pMut += Vector2D(1, 1)
        #expect(pMut == Point2D(4, 4))
        pMut -= Point2D(1, 1)
        #expect(pMut == Point2D(3, 3))
        pMut -= Vector2D(1, 1)
        #expect(pMut == Point2D(2, 2))

        // Comparisons and metrics
        #expect(Point2D(1, 2) < Point2D(2, 1))
        #expect(Point2D(1, 1) < Point2D(1, 2))
        #expect(p1.distance(to: p2) == 5.0)
        #expect(p1.distanceSquared(to: p2) == 25.0)
        #expect(p1.squaredDistance(to: p2) == 25.0)
        #expect(p1.dot(p2) == 50.0)
        #expect(p1.cross(p2) == 0.0)
        #expect(p1.normalized().magnitude.isApproximatelyEqual(to: 1.0, tolerance: 1e-6))
        #expect(Point2D.zero.normalized() == .zero)
        #expect(p1.theta > 0)
        #expect(Point2D(1, 0).angle(to: Point2D(0, 1)).isApproximatelyEqual(to: .pi / 2, tolerance: 1e-6))

        let rotated = Point2D(1, 0).rotated(byAngle: .pi / 2, around: .zero)
        #expect(rotated.isApproximatelyEqual(to: Point2D(0, 1), tolerance: 1e-6))

        let lerped = Point2D(0, 0).lerp(to: Point2D(10, 10), t: 0.5)
        #expect(lerped == Point2D(5, 5))
        #expect(p1.description.contains("Point2D"))

        // Vector arithmetic
        #expect(v1 + v2 == Vector2D(4, 6))
        #expect(v2 - v1 == Vector2D(2, 2))
        #expect(-v1 == Vector2D(-1, -2))
        #expect(v1 * 3.0 == Vector2D(3, 6))
        #expect(3.0 * v1 == Vector2D(3, 6))
        #expect(Vector2D(4, 8) / 2.0 == Vector2D(2, 4))

        var vMut = Vector2D(1, 1)
        vMut += Vector2D(2, 2)
        #expect(vMut == Vector2D(3, 3))
        vMut -= Vector2D(1, 1)
        #expect(vMut == Vector2D(2, 2))

        #expect(v2.magnitude == 5.0)
        #expect(v2.magnitudeSquared == 25.0)
        #expect(v2.dot(v1) == 11.0)
        #expect(v2.cross(v1) == 2.0)
        #expect(v2.normalized().magnitude.isApproximatelyEqual(to: 1.0, tolerance: 1e-6))
        #expect(Vector2D.zero.normalized() == .zero)
        #expect(v1.distance(to: v2) > 0)
        #expect(v1.distanceSquared(to: v2) > 0)
        #expect(Vector2D(1, 0).angle == 0)
        #expect(Vector2D(1, 0).rotated(by: .pi / 2).isApproximatelyEqual(to: Vector2D(0, 1), tolerance: 1e-6))
        #expect(Vector2D(0, 0).lerp(to: Vector2D(10, 10), t: 0.25) == Vector2D(2.5, 2.5))
        #expect(v1.description.contains("Vector2D"))

        #if canImport(CoreGraphics)
        let cgP = p1.cgPoint
        #expect(Point2D(cgP) == p1)
        #endif
    }

    @Test("Size2D and EdgeInsets2D")
    func testSizeAndInsets() {
        let s = Size2D(width: 100, height: 50)
        let s2 = Size2D(80, 40)
        #expect(s2.aspectRatio == 2.0)
        #expect(s.aspectRatio == 2.0)
        #expect(s.area == 5000.0)
        #expect(s.isPositive)
        #expect(!Size2D.zero.isPositive)
        #expect(Size2D(width: 10, height: 0).aspectRatio == 0)

        let clamped = Size2D(150, 20).clamped(min: Size2D(20, 30), max: Size2D(120, 80))
        #expect(clamped == Size2D(120, 30))

        #expect(s.scaled(by: 2.0) == Size2D(200, 100))
        #expect(s.scaled(x: 0.5, y: 2.0) == Size2D(50, 100))
        #expect(s.isApproximatelyEqual(to: Size2D(100.0000000001, 50.0)))
        #expect(s.description.contains("Size2D"))

        #if canImport(CoreGraphics)
        let cgS = s.cgSize
        #expect(Size2D(cgS) == s)
        #endif

        let insets = EdgeInsets2D(top: 10, left: 15, bottom: 20, right: 25)
        #expect(insets.horizontalTotal == 40)
        #expect(insets.verticalTotal == 30)
        #expect(EdgeInsets2D(all: 5).horizontalTotal == 10)
        #expect(EdgeInsets2D(horizontal: 12, vertical: 8).verticalTotal == 16)
        #expect(insets.description.contains("EdgeInsets2D"))
    }

    @Test("Rect2D geometric calculations and anchors")
    func testRect2D() {
        let r = Rect2D(x: 10, y: 20, width: 100, height: 80)
        let rNorm = Rect2D(x: 110, y: 100, width: -100, height: -80)
        #expect(rNorm == r)

        let rCenter = Rect2D(center: Point2D(60, 60), size: Size2D(100, 80))
        #expect(rCenter == r)

        let rCorners = Rect2D(p1: Point2D(10, 20), p2: Point2D(110, 100))
        #expect(rCorners == r)

        #expect(r.minX == 10)
        #expect(r.midX == 60)
        #expect(r.maxX == 110)
        #expect(r.minY == 20)
        #expect(r.midY == 60)
        #expect(r.maxY == 100)
        #expect(r.center == Point2D(60, 60))
        #expect(r.topLeft == Point2D(10, 20))
        #expect(r.topRight == Point2D(110, 20))
        #expect(r.bottomLeft == Point2D(10, 100))
        #expect(r.bottomRight == Point2D(110, 100))
        #expect(r.topMiddle == Point2D(60, 20))
        #expect(r.bottomMiddle == Point2D(60, 100))
        #expect(r.leftMiddle == Point2D(10, 60))
        #expect(r.rightMiddle == Point2D(110, 60))

        #expect(r.contains(Point2D(50, 50)))
        #expect(r.contains(point: Point2D(50, 50)))
        #expect(!r.contains(Point2D(0, 0)))

        let subR = Rect2D(x: 20, y: 30, width: 40, height: 40)
        #expect(r.contains(subR))
        #expect(r.contains(rect: subR))

        let r2 = Rect2D(x: 60, y: 60, width: 100, height: 100)
        #expect(r.intersects(r2))
        #expect(r.intersects(rect: r2))

        let isect = r.intersection(with: r2)
        #expect(isect == Rect2D(x: 60, y: 60, width: 50, height: 40))

        let disjoint = r.intersection(with: Rect2D(x: 200, y: 200, width: 10, height: 10))
        #expect(disjoint == nil)

        let unionR = r.union(with: r2)
        #expect(unionR == Rect2D(x: 10, y: 20, width: 150, height: 140))

        let inset = r.insetBy(dx: 10, dy: 10)
        #expect(inset == Rect2D(x: 20, y: 30, width: 80, height: 60))

        let expanded = r.expandedBy(dx: 10, dy: 10)
        #expect(expanded == Rect2D(x: 0, y: 10, width: 120, height: 100))

        let offset = r.offsetBy(dx: 5, dy: 5)
        #expect(offset == Rect2D(x: 15, y: 25, width: 100, height: 80))

        let insetsApplied = r.insetBy(insets: EdgeInsets2D(top: 5, left: 10, bottom: 15, right: 20))
        #expect(insetsApplied == Rect2D(x: 20, y: 25, width: 70, height: 60))

        #expect(!r.isEmpty)
        #expect(Rect2D.zero.isEmpty)
        #expect(r.isApproximatelyEqual(to: Rect2D(x: 10.0000000001, y: 20, width: 100, height: 80)))
        #expect(r.description.contains("Rect2D"))

        #if canImport(CoreGraphics)
        let cgR = r.cgRect
        #expect(Rect2D(cgR) == r)
        #endif
    }

    @Test("Line2D segment intersection and projection")
    func testLine2D() {
        let l1 = Line2D(start: Point2D(0, 0), end: Point2D(10, 0))
        let l2 = Line2D(x1: 5, y1: -5, x2: 5, y2: 5)

        #expect(l1.length == 10.0)
        #expect(l1.lengthSquared == 100.0)
        #expect(l1.dx == 10.0)
        #expect(l1.dy == 0.0)
        #expect(l1.angle == 0.0)
        #expect(l1.midpoint == Point2D(5, 0))
        #expect(l1.unitVector == Vector2D(1, 0))
        #expect(l1.normal == Vector2D(0, 1))

        #expect(l1.point(at: 0.5) == Point2D(5, 0))
        #expect(l1.projectionParameter(for: Point2D(5, 3)) == 0.5)
        #expect(l1.closestPoint(to: Point2D(5, 3)) == Point2D(5, 0))
        #expect(l1.closestPoint(to: Point2D(-5, 0)) == Point2D(0, 0))
        #expect(l1.closestPoint(to: Point2D(15, 0)) == Point2D(10, 0))
        #expect(l1.distance(to: Point2D(5, 3)) == 3.0)

        #expect(l1.intersects(l2))
        let hit = l1.intersection(with: l2)
        #expect(hit != nil)
        #expect(hit!.isApproximatelyEqual(to: Point2D(5, 0)))

        let parallel = Line2D(x1: 0, y1: 5, x2: 10, y2: 5)
        #expect(l1.intersection(with: parallel) == nil)

        let rect = Rect2D(x: 2, y: -2, width: 6, height: 4)
        let hits = l1.intersects(rect: rect)
        #expect(hits.count == 2)
        #expect(l1.description.contains("Line2D"))
    }

    @Test("Polygon2D area, centroid, containment, and clipping")
    func testPolygon2D() {
        let square = Polygon2D(vertices: [
            Point2D(0, 0),
            Point2D(10, 0),
            Point2D(10, 10),
            Point2D(0, 10)
        ])

        #expect(square.count == 4)
        #expect(!square.isEmpty)
        #expect(square.area == 100.0)
        #expect(square.signedArea == -100.0 || square.signedArea == 100.0)
        #expect(square.perimeter == 40.0)
        #expect(square.centroid.isApproximatelyEqual(to: Point2D(5, 5)))
        #expect(square.boundingBox == Rect2D(x: 0, y: 0, width: 10, height: 10))
        #expect(square.contains(Point2D(5, 5)))
        #expect(square.contains(point: Point2D(5, 5)))
        #expect(!square.contains(Point2D(15, 5)))
        #expect(square.edges.count == 4)
        #expect(square.isConvex)

        // Convex hull
        let concave = Polygon2D(vertices: [
            Point2D(0, 0),
            Point2D(10, 0),
            Point2D(5, 5),
            Point2D(10, 10),
            Point2D(0, 10)
        ])
        let hull = concave.convexHull()
        #expect(hull.count == 4)

        // Clipping
        let clipRect = Rect2D(x: 5, y: 5, width: 10, height: 10)
        let clipped = square.clipped(to: clipRect)
        #expect(clipped.area.isApproximatelyEqual(to: 25.0, tolerance: 1e-4))
        #expect(square.description.contains("Polygon2D"))
    }

    @Test("Polyline2D arc-length, sampling, and simplification")
    func testPolyline2D() {
        let poly = Polyline2D(points: [
            Point2D(0, 0),
            Point2D(10, 0),
            Point2D(10, 10),
            Point2D(20, 10)
        ])

        #expect(poly.count == 4)
        #expect(!poly.isEmpty)
        #expect(poly.segments.count == 3)
        #expect(poly.length == 30.0)
        #expect(poly.boundingBox == Rect2D(x: 0, y: 0, width: 20, height: 10))

        #expect(poly.point(at: 0.0) == Point2D(0, 0))
        #expect(poly.point(at: 1.0) == Point2D(20, 10))
        #expect(poly.point(at: 1.0 / 3.0).isApproximatelyEqual(to: Point2D(10, 0)))

        #expect(poly.closestPoint(to: Point2D(5, 2)) == Point2D(5, 0))
        #expect(poly.distance(to: Point2D(5, 2)) == 2.0)

        // RDP Simplification
        let noisy = Polyline2D(points: [
            Point2D(0, 0),
            Point2D(5, 0.1),
            Point2D(10, 0)
        ])
        let simplified = noisy.simplified(tolerance: 0.5)
        #expect(simplified.count == 2)
        #expect(poly.description.contains("Polyline2D"))
    }

    @Test("Circle2D containment and intersections")
    func testCircle2D() {
        let c = Circle2D(center: Point2D(10, 10), radius: 5)
        #expect(c.diameter == 10.0)
        #expect(c.area.isApproximatelyEqual(to: .pi * 25.0))
        #expect(c.circumference.isApproximatelyEqual(to: 2 * .pi * 5.0))
        #expect(c.boundingBox == Rect2D(x: 5, y: 5, width: 10, height: 10))

        #expect(c.contains(Point2D(10, 10)))
        #expect(c.contains(point: Point2D(13, 14)))
        #expect(!c.contains(Point2D(20, 20)))

        let c2 = Circle2D(x: 18, y: 10, radius: 5)
        #expect(c.intersects(circle: c2))
        let cDisjoint = Circle2D(x: 30, y: 30, radius: 2)
        #expect(!c.intersects(circle: cDisjoint))

        let r = Rect2D(x: 12, y: 12, width: 10, height: 10)
        #expect(c.intersects(rect: r))

        let l = Line2D(x1: 0, y1: 10, x2: 20, y2: 10)
        let hits = c.intersectionPoints(with: l)
        #expect(hits.count == 2)
        #expect(hits[0].isApproximatelyEqual(to: Point2D(5, 10)))
        #expect(hits[1].isApproximatelyEqual(to: Point2D(15, 10)))
        #expect(c.description.contains("Circle2D"))
    }

    @Test("Transform2D affine concatenation, inversion, and application")
    func testTransform2D() {
        let tIdent = Transform2D.identity
        #expect(tIdent.isInvertible)
        #expect(tIdent.determinant == 1.0)

        let tTrans = Transform2D.translation(x: 10, y: 20)
        let tScale = Transform2D.scale(x: 2, y: 3)
        let tRot = Transform2D.rotation(radians: .pi / 2)
        #expect(tRot.apply(to: Point2D(1, 0)).isApproximatelyEqual(to: Point2D(0, 1), tolerance: 1e-6))

        let combined = tTrans.concatenating(tScale)
        let p = Point2D(5, 5)
        let pTransformed = combined.apply(to: p)
        #expect(pTransformed == Point2D(30, 75)) // (5*2 + 10*2)? wait: (5+10)*2? let's check order:
        // combined = tTrans * tScale:
        // [1 0 10] * [2 0 0] = [2 0 20] -> let's test directly with apply
        #expect(tTrans.apply(to: p) == Point2D(15, 25))
        #expect(tScale.apply(to: p) == Point2D(10, 15))

        let v = Vector2D(5, 5)
        #expect(tTrans.apply(to: v) == Vector2D(5, 5))
        #expect(tScale.apply(to: v) == Vector2D(10, 15))

        let inv = tTrans.inverted()
        #expect(inv != nil)
        #expect(inv!.apply(to: Point2D(15, 25)) == p)

        let chained = Transform2D.identity
            .translatedBy(x: 10, y: 10)
            .scaledBy(2.0)
            .rotatedBy(radians: .pi / 4)
        #expect(chained.isInvertible)

        let rect = Rect2D(x: 0, y: 0, width: 10, height: 10)
        let rectTransformed = tTrans.apply(to: rect)
        #expect(rectTransformed == Rect2D(x: 10, y: 20, width: 10, height: 10))

        #expect(tTrans.isApproximatelyEqual(to: Transform2D.translation(x: 10, y: 20)))
        #expect(tTrans.description.contains("Transform2D"))

        // AffineTransform2D alias compatibility
        let alias: AffineTransform2D = tTrans
        #expect(alias == tTrans)

        #if canImport(CoreGraphics)
        let cgT = tTrans.cgTransform
        #expect(Transform2D(cgT).isApproximatelyEqual(to: tTrans))
        #endif
    }

    @Test("Bézier curves (Quadratic & Cubic)")
    func testBezierCurves() {
        let q = QuadraticBezier2D(
            p0: Point2D(0, 0),
            p1: Point2D(5, 10),
            p2: Point2D(10, 0)
        )

        #expect(q.point(at: 0.0) == Point2D(0, 0))
        #expect(q.point(at: 1.0) == Point2D(10, 0))
        #expect(q.point(at: 0.5) == Point2D(5, 5))
        #expect(q.derivative(at: 0.5) == Vector2D(10, 0))
        #expect(q.arcLength() > 10.0)

        let qSplit = q.split(at: 0.5)
        #expect(qSplit.left.point(at: 1.0) == q.point(at: 0.5))
        #expect(qSplit.right.point(at: 0.0) == q.point(at: 0.5))
        #expect(q.boundingBox.height >= 5.0)

        let elevated = q.elevateToCubic()
        #expect(elevated.point(at: 0.5).isApproximatelyEqual(to: q.point(at: 0.5)))
        #expect(q.description.contains("QuadraticBezier2D"))

        let c = CubicBezier2D(
            p0: Point2D(0, 0),
            p1: Point2D(0, 10),
            p2: Point2D(10, 10),
            p3: Point2D(10, 0)
        )

        #expect(c.point(at: 0.0) == Point2D(0, 0))
        #expect(c.point(at: 1.0) == Point2D(10, 0))
        #expect(c.tangent(at: 0.0).magnitude.isApproximatelyEqual(to: 1.0, tolerance: 1e-6))
        #expect(c.normal(at: 0.0).magnitude.isApproximatelyEqual(to: 1.0, tolerance: 1e-6))
        #expect(c.arcLength() > 10.0)

        let cSplit = c.split(at: 0.5)
        #expect(cSplit.left.point(at: 1.0).isApproximatelyEqual(to: c.point(at: 0.5)))
        #expect(cSplit.right.point(at: 0.0).isApproximatelyEqual(to: c.point(at: 0.5)))

        let cp = c.closestPoint(to: Point2D(5, 7.5))
        #expect(cp.y > 0)
        #expect(c.boundingBox.width >= 10.0)
        #expect(c.description.contains("CubicBezier2D"))

        #expect(QuadraticBezier2D.zero.p0 == .zero)
        #expect(CubicBezier2D.zero.p0 == .zero)
    }

    @Test("Additional VectorGeometry edge cases and branch coverage")
    func testGeometryEdgeCases() {
        // Line2D non-intersecting and tolerance
        let l1 = Line2D(start: Point2D(0, 0), end: Point2D(10, 0))
        let lNonIsect = Line2D(start: Point2D(5, 5), end: Point2D(5, 10))
        #expect(l1.intersection(with: lNonIsect) == nil)
        #expect(l1.isApproximatelyEqual(to: Line2D(start: Point2D(0, 0), end: Point2D(10, 0))))
        #expect(!l1.isApproximatelyEqual(to: Line2D(start: Point2D(0, 1), end: Point2D(10, 0))))
        #expect(Line2D.zero.length == 0)

        // Transform2D operators and chained delta
        let t1 = Transform2D.translation(x: 5, y: 5)
        let t2 = Transform2D.scale(x: 2, y: 2)
        let tMul = t1 * t2
        #expect(tMul.apply(to: Point2D(0, 0)) == Point2D(5, 5))
        #expect(tMul.apply(to: Point2D(1, 1)) == Point2D(7, 7))

        let tDelta = Transform2D.identity.translatedBy(Vector2D(10, 20))
        #expect(tDelta.apply(to: Point2D.zero) == Point2D(10, 20))

        let tRotAngle = Transform2D.identity.rotated(byAngle: .pi / 2)
        #expect(tRotAngle.apply(to: Point2D(1, 0)).isApproximatelyEqual(to: Point2D(0, 1), tolerance: 1e-6))

        let singular = Transform2D(a: 0, b: 0, c: 0, d: 0, tx: 0, ty: 0)
        #expect(!singular.isInvertible)
        #expect(singular.inverted() == nil)

        // Polygon2D edge cases: non-convex, collinear centroid, 4-sided clipping
        let nonConvex = Polygon2D(vertices: [
            Point2D(0, 0),
            Point2D(10, 0),
            Point2D(5, 2),
            Point2D(10, 10),
            Point2D(0, 10)
        ])
        #expect(!nonConvex.isConvex)

        let collinear = Polygon2D(vertices: [Point2D(0, 0), Point2D(5, 0), Point2D(10, 0)])
        #expect(collinear.centroid.y == 0)

        let single = Polygon2D(vertices: [Point2D(3, 4)])
        #expect(single.centroid == Point2D(3, 4))
        #expect(Polygon2D(vertices: []).centroid == .zero)
        #expect(Polygon2D(vertices: []).boundingBox == .zero)
        #expect(Polygon2D(vertices: []).edges.isEmpty)
        #expect(!Polygon2D(vertices: []).contains(Point2D(1, 1)))

        let bigSquare = Polygon2D(vertices: [
            Point2D(-10, -10),
            Point2D(20, -10),
            Point2D(20, 20),
            Point2D(-10, 20)
        ])
        let innerRect = Rect2D(x: 0, y: 0, width: 10, height: 10)
        let clippedAll = bigSquare.clipped(to: innerRect)
        #expect(clippedAll.area.isApproximatelyEqual(to: 100.0, tolerance: 1e-4))

        // Bézier curve extrema on both axes
        let sCurve = CubicBezier2D(
            p0: Point2D(0, 0),
            p1: Point2D(20, 30),
            p2: Point2D(-10, 10),
            p3: Point2D(15, 40)
        )
        #expect(sCurve.boundingBox.width > 0)
        #expect(sCurve.boundingBox.height > 0)
        #expect(sCurve.boundingBox.minY >= 0)
    }
}


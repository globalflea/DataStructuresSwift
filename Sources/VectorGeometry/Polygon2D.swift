// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation

/// A 2D closed polygon defined by a sequence of vertex points.
public struct Polygon2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var vertices: [Point2D]

    @inlinable
    public init(vertices: [Point2D]) {
        self.vertices = vertices
    }

    @inlinable
    public init(points: [Point2D]) {
        self.vertices = points
    }

    @inlinable
    public var points: [Point2D] {
        get { vertices }
        set { vertices = newValue }
    }

    @inlinable public var count: Int { vertices.count }
    @inlinable public var vertexCount: Int { vertices.count }
    @inlinable public var isEmpty: Bool { vertices.isEmpty }

    /// Bounding rectangle tightly enclosing all polygon vertices.
    public var boundingBox: Rect2D {
        guard !vertices.isEmpty else { return .zero }
        var minX = vertices[0].x
        var maxX = vertices[0].x
        var minY = vertices[0].y
        var maxY = vertices[0].y

        for v in vertices.dropFirst() {
            if v.x < minX { minX = v.x }
            if v.x > maxX { maxX = v.x }
            if v.y < minY { minY = v.y }
            if v.y > maxY { maxY = v.y }
        }
        return Rect2D(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Signed area calculated using the Gauss Shoelace Formula (positive = counter-clockwise, negative = clockwise).
    public var signedArea: Double {
        guard vertices.count >= 3 else { return 0.0 }
        var acc = 0.0
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            acc += (vertices[i].x * vertices[j].y) - (vertices[j].x * vertices[i].y)
        }
        return acc * 0.5
    }

    /// Absolute surface area enclosed by the polygon.
    @inlinable
    public var area: Double {
        abs(signedArea)
    }

    /// Total perimeter length along all edges.
    public var perimeter: Double {
        guard vertices.count >= 2 else { return 0.0 }
        var total = 0.0
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            total += vertices[i].distance(to: vertices[j])
        }
        return total
    }

    /// Geometric centroid (center of mass).
    public var centroid: Point2D {
        guard vertices.count >= 3 else {
            if vertices.isEmpty { return .zero }
            let avgX = vertices.reduce(0.0) { $0 + $1.x } / Double(vertices.count)
            let avgY = vertices.reduce(0.0) { $0 + $1.y } / Double(vertices.count)
            return Point2D(x: avgX, y: avgY)
        }

        var cx = 0.0
        var cy = 0.0
        let n = vertices.count
        let sArea = signedArea

        guard abs(sArea) > 1e-9 else {
            let avgX = vertices.reduce(0.0) { $0 + $1.x } / Double(n)
            let avgY = vertices.reduce(0.0) { $0 + $1.y } / Double(n)
            return Point2D(x: avgX, y: avgY)
        }

        for i in 0..<n {
            let j = (i + 1) % n
            let factor = (vertices[i].x * vertices[j].y) - (vertices[j].x * vertices[i].y)
            cx += (vertices[i].x + vertices[j].x) * factor
            cy += (vertices[i].y + vertices[j].y) * factor
        }

        let denom = 6.0 * sArea
        return Point2D(x: cx / denom, y: cy / denom)
    }

    /// Point containment test using the Ray Casting (Even-Odd) algorithm.
    public func contains(_ point: Point2D) -> Bool {
        guard vertices.count >= 3 else { return false }
        guard boundingBox.contains(point) else { return false }

        var inside = false
        let n = vertices.count
        var j = n - 1

        for i in 0..<n {
            let vi = vertices[i]
            let vj = vertices[j]

            if ((vi.y > point.y) != (vj.y > point.y)) &&
                (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    @inlinable
    public func contains(point: Point2D) -> Bool {
        contains(point)
    }

    /// Consecutive line segments forming the perimeter of the polygon.
    public var edges: [Line2D] {
        guard vertices.count >= 2 else { return [] }
        var result: [Line2D] = []
        let n = vertices.count
        for i in 0..<n {
            let j = (i + 1) % n
            result.append(Line2D(start: vertices[i], end: vertices[j]))
        }
        return result
    }

    /// Determines if the polygon is strictly convex.
    public var isConvex: Bool {
        guard vertices.count >= 3 else { return false }
        var sign: Double = 0
        let n = vertices.count
        for i in 0..<n {
            let p0 = vertices[i]
            let p1 = vertices[(i + 1) % n]
            let p2 = vertices[(i + 2) % n]

            let dx1 = p1.x - p0.x
            let dy1 = p1.y - p0.y
            let dx2 = p2.x - p1.x
            let dy2 = p2.y - p1.y
            let cross = dx1 * dy2 - dy1 * dx2

            if abs(cross) > 1e-9 {
                if sign == 0 {
                    sign = cross
                } else if (cross > 0 && sign < 0) || (cross < 0 && sign > 0) {
                    return false
                }
            }
        }
        return true
    }

    /// Computes the convex hull of the vertices using Andrew's Monotone Chain algorithm.
    public func convexHull() -> Polygon2D {
        guard vertices.count > 3 else { return self }
        let sorted = vertices.sorted()

        var lower: [Point2D] = []
        for p in sorted {
            while lower.count >= 2 {
                let p1 = lower[lower.count - 2]
                let p2 = lower[lower.count - 1]
                if (p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x) <= 1e-9 {
                    lower.removeLast()
                } else {
                    break
                }
            }
            lower.append(p)
        }

        var upper: [Point2D] = []
        for p in sorted.reversed() {
            while upper.count >= 2 {
                let p1 = upper[upper.count - 2]
                let p2 = upper[upper.count - 1]
                if (p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x) <= 1e-9 {
                    upper.removeLast()
                } else {
                    break
                }
            }
            upper.append(p)
        }

        lower.removeLast()
        upper.removeLast()
        return Polygon2D(vertices: lower + upper)
    }

    /// Clips the polygon against an axis-aligned bounding box using Sutherland-Hodgman clipping.
    public func clipped(to rect: Rect2D) -> Polygon2D {
        guard !vertices.isEmpty else { return self }
        var output = vertices

        // Clip Left
        output = clipEdge(output) { $0.x >= rect.minX } intersect: { p1, p2 in
            let t = (rect.minX - p1.x) / (p2.x - p1.x)
            return Point2D(x: rect.minX, y: p1.y + t * (p2.y - p1.y))
        }
        // Clip Right
        output = clipEdge(output) { $0.x <= rect.maxX } intersect: { p1, p2 in
            let t = (rect.maxX - p1.x) / (p2.x - p1.x)
            return Point2D(x: rect.maxX, y: p1.y + t * (p2.y - p1.y))
        }
        // Clip Top
        output = clipEdge(output) { $0.y >= rect.minY } intersect: { p1, p2 in
            let t = (rect.minY - p1.y) / (p2.y - p1.y)
            return Point2D(x: p1.x + t * (p2.x - p1.x), y: rect.minY)
        }
        // Clip Bottom
        output = clipEdge(output) { $0.y <= rect.maxY } intersect: { p1, p2 in
            let t = (rect.maxY - p1.y) / (p2.y - p1.y)
            return Point2D(x: p1.x + t * (p2.x - p1.x), y: rect.maxY)
        }

        return Polygon2D(vertices: output)
    }

    /// Clips this polygon against a convex clipping polygon using the Sutherland-Hodgman algorithm.
    public func clipped(against clipPoly: Polygon2D) -> Polygon2D {
        guard !isEmpty && !clipPoly.isEmpty else { return Polygon2D(vertices: []) }
        var outputList = vertices

        let clipCount = clipPoly.vertices.count
        for i in 0..<clipCount {
            let cp1 = clipPoly.vertices[i]
            let cp2 = clipPoly.vertices[(i + 1) % clipCount]

            let inputList = outputList
            outputList.removeAll()
            guard !inputList.isEmpty else { break }

            var s = inputList[inputList.count - 1]
            for e in inputList {
                if isInsideEdge(p: e, cp1: cp1, cp2: cp2) {
                    if isInsideEdge(p: s, cp1: cp1, cp2: cp2) {
                        outputList.append(e)
                    } else {
                        outputList.append(polygonIntersection(cp1: cp1, cp2: cp2, s: s, e: e))
                        outputList.append(e)
                    }
                } else if isInsideEdge(p: s, cp1: cp1, cp2: cp2) {
                    outputList.append(polygonIntersection(cp1: cp1, cp2: cp2, s: s, e: e))
                }
                s = e
            }
        }
        return Polygon2D(vertices: outputList)
    }

    private func isInsideEdge(p: Point2D, cp1: Point2D, cp2: Point2D) -> Bool {
        isLeft(p0: cp1, p1: cp2, p2: p) >= 0
    }

    private func isLeft(p0: Point2D, p1: Point2D, p2: Point2D) -> Double {
        (p1.x - p0.x) * (p2.y - p0.y) - (p2.x - p0.x) * (p1.y - p0.y)
    }

    private func polygonIntersection(cp1: Point2D, cp2: Point2D, s: Point2D, e: Point2D) -> Point2D {
        let dc = Point2D(x: cp1.x - cp2.x, y: cp1.y - cp2.y)
        let dp = Point2D(x: s.x - e.x, y: s.y - e.y)
        let n1 = cp1.x * cp2.y - cp1.y * cp2.x
        let n2 = s.x * e.y - s.y * e.x
        let n3 = 1.0 / (dc.x * dp.y - dc.y * dp.x)
        return Point2D(
            x: (n1 * dp.x - n2 * dc.x) * n3,
            y: (n1 * dp.y - n2 * dc.y) * n3
        )
    }

    private func clipEdge(
        _ points: [Point2D],
        inside: (Point2D) -> Bool,
        intersect: (Point2D, Point2D) -> Point2D
    ) -> [Point2D] {
        guard !points.isEmpty else { return [] }
        var result: [Point2D] = []
        var s = points.last!
        for e in points {
            if inside(e) {
                if inside(s) {
                    result.append(e)
                } else {
                    result.append(intersect(s, e))
                    result.append(e)
                }
            } else if inside(s) {
                result.append(intersect(s, e))
            }
            s = e
        }
        return result
    }

    public var description: String {
        "Polygon2D(\(vertices.count) vertices)"
    }
}

# ``VectorGeometry``

Allocation-free, mathematically rigorous 2D affine geometry, parametric Bézier curves, and polygon algorithms.

## Overview

`VectorGeometry` provides the fundamental geometric primitives and transformation algebra for vector rendering, interactive diagramming engines (**`JointSwift`**), and data visualization (**`EchartsSwift`**).

Designed around affine space theory ($\mathbb{A}^2$ vs $\mathbb{R}^2$), `VectorGeometry` enforces compile-time differentiation between points (locations) and vectors (displacements), preventing illegal operations like adding two points while guaranteeing mathematical purity and SIMD-aligned performance.

### Architecture

```
                  +--------------------------------+
                  |           Transform2D          |
                  | (3x3 Homogeneous Affine Matrix)|
                  +--------------------------------+
                                  |
         +------------------------+------------------------+
         |                        |                        |
         v                        v                        v
+-----------------+      +-----------------+      +-----------------+
|     Point2D     |      |    Vector2D     |      |     Rect2D      |
| (Affine Space)  |      | (Vector Space)  |      |   (AABB Box)    |
+-----------------+      +-----------------+      +-----------------+
         |                        |
         +-----------+------------+
                     |
                     v
+----------------------------------------------------------+
| Curves: Line2D, Circle2D, Ellipse2D, Arc2D               |
| Béziers: QuadraticBezier2D, CubicBezier2D                |
| Polygons: Polygon2D (Shoelace & Sutherland-Hodgman)      |
| Polylines: Polyline2D (Ramer-Douglas-Peucker)            |
+----------------------------------------------------------+
```

## Topics

### Primitives & Vectors
- ``Point2D``
- ``Vector2D``
- ``Size2D``
- ``Rect2D``
- ``EdgeInsets2D``

### Affine Transformations
- ``Transform2D``

### Parametric Curves & Arcs
- ``Line2D``
- ``Circle2D``
- ``Ellipse2D``
- ``Arc2D``

### Bézier Curves & Splines
- ``QuadraticBezier2D``
- ``CubicBezier2D``
- ``BezierClosestPointResult``

### Polygons & Polylines
- ``Polygon2D``
- ``Polyline2D``

## See Also
- [02 Vector Geometry & Affine Transforms](file:///Users/globalflea/Xplore/MeridianCore/Docs/Design/02_VECTOR_GEOMETRY_AND_AFFINE_TRANSFORMS.md)

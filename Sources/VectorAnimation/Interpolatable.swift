// ===----------------------------------------------------------------------===
//
// This source file is part of the MeridianCore open source project
//
// Copyright (c) 2026 Apple Inc. and the MeridianCore project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// ===----------------------------------------------------------------------===

import Foundation
import VectorGeometry

/// A type that can be linearly interpolated between a start and target state.
public protocol Interpolatable: Sendable {
    /// Linearly interpolates between `self` and `target` using parameter `progress` in [0, 1].
    func interpolated(to target: Self, progress: Double) -> Self
}

extension Double: Interpolatable {
    @inlinable
    public func interpolated(to target: Double, progress: Double) -> Double {
        self + (target - self) * progress
    }
}

extension Float: Interpolatable {
    @inlinable
    public func interpolated(to target: Float, progress: Double) -> Float {
        self + (target - self) * Float(progress)
    }
}

extension Int: Interpolatable {
    @inlinable
    public func interpolated(to target: Int, progress: Double) -> Int {
        Int(Double(self) + Double(target - self) * progress)
    }
}

extension Point2D: Interpolatable {
    @inlinable
    public func interpolated(to target: Point2D, progress: Double) -> Point2D {
        lerp(to: target, t: progress)
    }
}

extension Vector2D: Interpolatable {
    @inlinable
    public func interpolated(to target: Vector2D, progress: Double) -> Vector2D {
        lerp(to: target, t: progress)
    }
}

extension Size2D: Interpolatable {
    @inlinable
    public func interpolated(to target: Size2D, progress: Double) -> Size2D {
        Size2D(
            width: width.interpolated(to: target.width, progress: progress),
            height: height.interpolated(to: target.height, progress: progress)
        )
    }
}

extension Rect2D: Interpolatable {
    @inlinable
    public func interpolated(to target: Rect2D, progress: Double) -> Rect2D {
        Rect2D(
            origin: origin.interpolated(to: target.origin, progress: progress),
            size: size.interpolated(to: target.size, progress: progress)
        )
    }
}

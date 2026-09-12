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

/// A 2D dimension representing width and height.
public struct Size2D: Sendable, Hashable, Equatable, Codable, CustomStringConvertible {
    public var width: Double
    public var height: Double

    public static let zero = Size2D(width: 0, height: 0)

    @inlinable
    public init(width: Double, height: Double) {
        self.width = max(0, width)
        self.height = max(0, height)
    }

    @inlinable
    public init(_ width: Double, _ height: Double) {
        self.init(width: width, height: height)
    }

    /// Aspect ratio (width / height), or zero if height is near zero.
    @inlinable
    public var aspectRatio: Double {
        height > 1e-9 ? width / height : 0
    }

    /// Total surface area.
    @inlinable
    public var area: Double {
        width * height
    }

    /// Whether both dimensions are strictly greater than zero.
    @inlinable
    public var isPositive: Bool {
        width > 0 && height > 0
    }

    /// Clamps dimensions to given minimum and maximum sizes.
    @inlinable
    public func clamped(min: Size2D, max: Size2D) -> Size2D {
        Size2D(
            width: Swift.max(min.width, Swift.min(max.width, width)),
            height: Swift.max(min.height, Swift.min(max.height, height))
        )
    }

    /// Scales dimensions uniformly by a scalar factor.
    @inlinable
    public func scaled(by factor: Double) -> Size2D {
        Size2D(width: width * factor, height: height * factor)
    }

    /// Scales dimensions non-uniformly.
    @inlinable
    public func scaled(x sx: Double, y sy: Double) -> Size2D {
        Size2D(width: width * sx, height: height * sy)
    }

    /// Epsilon-tolerant comparison.
    public func isApproximatelyEqual(to other: Size2D, tolerance: Double = 1e-9) -> Bool {
        abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }

    public var description: String {
        "Size2D(\(String(format: "%.3f", width)) × \(String(format: "%.3f", height)))"
    }

    #if canImport(CoreGraphics)
    @inlinable
    public init(_ cgSize: CGSize) {
        self.width = max(0, Double(cgSize.width))
        self.height = max(0, Double(cgSize.height))
    }

    @inlinable
    public var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
    #endif
}

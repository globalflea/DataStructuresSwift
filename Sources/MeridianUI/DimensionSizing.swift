//
// DimensionSizing.swift
// MeridianUI
//
// Universal orthogonal dimension sizing specification for modular panels, panes, and widgets.
// Allows panes to declare independent horizontal and vertical sizing constraints.
//

import SwiftUI
import Foundation

/// Sizing policy for a single dimension (width or height) of a container, panel, or widget.
///
/// Designed to govern sizing behavior orthogonally along the horizontal and vertical axes:
/// - `.fillParent`: Dimension locks dynamically to 100% of the parent container frame;
///   manual drag handles for this axis are suppressed.
/// - `.resizable`: Dimension can be dynamically adjusted by the user via splitters or drag handles
///   within defined minimum, maximum, and default bounds.
/// - `.fixed`: Dimension remains constant and immutable at a specified point value.
/// - `.proportional`: Dimension occupies a proportional fraction of the available parent dimension.
public enum DimensionSizing: Sendable, Equatable {
    /// Dimension automatically fills 100% of the parent container's available extent.
    /// Manual resize handles along this axis are disabled.
    case fillParent

    /// Dimension is manually resizable by the user within constrained bounds.
    ///
    /// - Parameters:
    ///   - min: Minimum permissible size in points.
    ///   - max: Maximum permissible size in points.
    ///   - defaultSize: Initial or reset size in points.
    case resizable(min: CGFloat, max: CGFloat, defaultSize: CGFloat)

    /// Dimension is fixed at an exact point value.
    ///
    /// - Parameter points: Fixed dimension size in points.
    case fixed(CGFloat)

    /// Dimension is allocated a proportional fraction of the parent container (e.g. 0.5 for 50%).
    ///
    /// - Parameter fraction: Value between 0.0 and 1.0 representing proportion.
    case proportional(Double)

    // MARK: - Classification Helpers

    /// Indicates whether this dimension allows manual resizing via drag handles.
    public var isResizable: Bool {
        if case .resizable = self { return true }
        return false
    }

    /// Indicates whether this dimension automatically follows the parent container.
    public var isFillParent: Bool {
        if case .fillParent = self { return true }
        return false
    }

    /// Indicates whether this dimension is fixed at a static size.
    public var isFixed: Bool {
        if case .fixed = self { return true }
        return false
    }

    /// Indicates whether this dimension allocates a proportional ratio.
    public var isProportional: Bool {
        if case .proportional = self { return true }
        return false
    }

    /// Default or fallback point size associated with this specification, if applicable.
    public var defaultSize: CGFloat? {
        switch self {
        case .fillParent:
            return nil
        case .resizable(_, _, let defaultSize):
            return defaultSize
        case .fixed(let size):
            return size
        case .proportional:
            return nil
        }
    }

    /// Clamps a candidate size against the constraints imposed by this specification.
    ///
    /// - Parameter candidate: The desired size in points.
    /// - Returns: The clamped size in points conforming to the constraints.
    public func clamp(_ candidate: CGFloat) -> CGFloat {
        switch self {
        case .fillParent:
            return candidate
        case .resizable(let min, let max, _):
            return Swift.min(Swift.max(candidate, min), max)
        case .fixed(let points):
            return points
        case .proportional:
            return candidate
        }
    }
}

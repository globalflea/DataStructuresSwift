//
// ToolContainer.swift
// MeridianUI
//
// Universal anchor-aware toolbar container supporting dynamic column/row capacity
// and asymmetric directional chevron toggle physics.
//

import SwiftUI

/// Placement anchor determining the docking edge and expansion physics for a `ToolContainer`.
public enum ToolbarAnchor: Sendable, Equatable {
    /// Anchored to the leading (left) edge; expands rightward.
    case leading

    /// Anchored to the trailing (right) edge; expands leftward.
    case trailing

    /// Anchored to the top edge; expands downward.
    case top

    /// Anchored to the bottom edge; expands upward.
    case bottom

    /// Indicates whether the anchor implies a vertical container (leading or trailing).
    public var isVertical: Bool {
        self == .leading || self == .trailing
    }

    /// Resolves the directional SF Symbol chevron name based on anchor position and expansion state.
    ///
    /// - Parameter isExpanded: Whether the container is expanded beyond its collapsed baseline (e.g. capacity > 1).
    /// - Returns: SF Symbol name matching the collapse/expand direction.
    public func chevronIcon(isExpanded: Bool) -> String {
        switch self {
        case .leading:
            // Collapsed: points right (>) to expand into workspace.
            // Expanded: points left (<) back towards anchor to collapse.
            return isExpanded ? "chevron.left" : "chevron.right"
        case .trailing:
            // Collapsed: points left (<) to expand into workspace.
            // Expanded: points right (>) back towards anchor to collapse.
            return isExpanded ? "chevron.right" : "chevron.left"
        case .top:
            // Collapsed: points down (v) to expand downward.
            // Expanded: points up (^) back towards anchor to collapse.
            return isExpanded ? "chevron.up" : "chevron.down"
        case .bottom:
            // Collapsed: points up (^) to expand upward.
            // Expanded: points down (v) back towards anchor to collapse.
            return isExpanded ? "chevron.down" : "chevron.up"
        }
    }
}

/// A generic, anchor-aware container for toolbars and action strips.
///
/// Features dynamic 1...N capacity expansion with automatic asymmetric chevron toggling.
/// When anchored vertically (leading or trailing), expanding increases column count.
/// When anchored horizontally (top or bottom), expanding increases row count.
public struct ToolContainer<Content: View>: View {
    public let anchor: ToolbarAnchor
    @Binding public var capacity: Int
    public let maxCapacity: Int
    public let slotDimension: CGFloat
    public let showToggleButton: Bool
    public let backgroundColor: Color
    public let borderColor: Color
    public let content: Content

    @State private var isButtonHovered: Bool = false

    /// Initializes a generic `ToolContainer`.
    ///
    /// - Parameters:
    ///   - anchor: Docking anchor (`.leading`, `.trailing`, `.top`, `.bottom`).
    ///   - capacity: Binding to the current column (or row) count.
    ///   - maxCapacity: Maximum capacity when expanded (default is 2).
    ///   - slotDimension: Width/height of each slot (default is 38pt).
    ///   - showToggleButton: Whether to display the bottom/end directional chevron toggle (default is true).
    ///   - backgroundColor: Container background fill (default is subtle translucent surface).
    ///   - borderColor: Divider/border stroke color (default is subtle border).
    ///   - content: ViewBuilder containing the toolbar tools or slots.
    public init(
        anchor: ToolbarAnchor = .leading,
        capacity: Binding<Int>,
        maxCapacity: Int = 2,
        slotDimension: CGFloat = 38,
        showToggleButton: Bool = true,
        backgroundColor: Color = Color(white: 0.11),
        borderColor: Color = Color(white: 0.22),
        @ViewBuilder content: () -> Content
    ) {
        self.anchor = anchor
        self._capacity = capacity
        self.maxCapacity = max(maxCapacity, 1)
        self.slotDimension = slotDimension
        self.showToggleButton = showToggleButton
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }

    /// Whether the container is currently expanded beyond its single-capacity baseline.
    public var isExpanded: Bool {
        capacity > 1
    }

    public var body: some View {
        Group {
            if anchor.isVertical {
                verticalLayout
            } else {
                horizontalLayout
            }
        }
    }

    // MARK: - Vertical Layout (Leading / Trailing)

    private var verticalLayout: some View {
        let totalWidth = CGFloat(max(1, capacity)) * slotDimension + 8

        return VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .padding(4)
            }

            if showToggleButton {
                Divider()
                    .overlay(borderColor)

                toggleButton
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: totalWidth)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(borderColor),
            alignment: anchor == .leading ? .trailing : .leading
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: capacity)
    }

    // MARK: - Horizontal Layout (Top / Bottom)

    private var horizontalLayout: some View {
        let totalHeight = CGFloat(max(1, capacity)) * slotDimension + 8

        return HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                content
                    .padding(4)
            }

            if showToggleButton {
                Divider()
                    .overlay(borderColor)

                toggleButton
                    .frame(width: 32)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(height: totalHeight)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(borderColor),
            alignment: anchor == .top ? .bottom : .top
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: capacity)
    }

    // MARK: - Directional Toggle Button

    private var toggleButton: some View {
        Button(action: toggleCapacity) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isButtonHovered ? Color.white.opacity(0.08) : Color.clear)
                    .padding(2)

                Image(systemName: anchor.chevronIcon(isExpanded: isExpanded))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isButtonHovered ? .white : Color(white: 0.65))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isButtonHovered = hovering
        }
        .help(isExpanded ? "Collapse toolbar" : "Expand toolbar")
    }

    private func toggleCapacity() {
        if capacity > 1 {
            capacity = 1
        } else {
            capacity = maxCapacity
        }
    }
}

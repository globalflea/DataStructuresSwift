//
// Panel.swift
// MeridianUI
//
// Modular container component combining a PanelHeader with arbitrary child content,
// governed by orthogonal horizontal and vertical DimensionSizing specifications.
//

import SwiftUI

/// A composable, reusable panel container hosting content beneath a configurable `PanelHeader`.
///
/// Designed to represent charts, inspectors, analytical subpanes, and tool widgets.
/// Sizing behavior is orthogonally declared via `horizontalSizing` and `verticalSizing`.
public struct Panel<Content: View, Accessory: View>: View {
    public let headerTitle: String
    public let headerSubtitle: String?
    public let headerStyle: HeaderStyle
    public let horizontalSizing: DimensionSizing
    public let verticalSizing: DimensionSizing
    public let isMaximized: Bool
    public let onMaximize: (@MainActor @Sendable () -> Void)?
    public let onClose: (@MainActor @Sendable () -> Void)?
    public let backgroundColor: Color
    public let borderColor: Color
    public let accessory: Accessory
    public let content: Content

    /// Initializes a generic `Panel` with custom accessory view.
    ///
    /// - Parameters:
    ///   - title: Panel header title.
    ///   - subtitle: Optional header subtitle or metadata label.
    ///   - style: Header presentation style (`.thick`, `.minimalist`, `.hidden`).
    ///   - horizontalSizing: Sizing rule along the horizontal axis (default: `.fillParent`).
    ///   - verticalSizing: Sizing rule along the vertical axis (default: `.fillParent`).
    ///   - isMaximized: Whether the panel is currently displayed full-bleed.
    ///   - onMaximize: Callback when maximize/restore is clicked.
    ///   - onClose: Callback when close is clicked.
    ///   - backgroundColor: Container background fill.
    ///   - borderColor: Outer border stroke color.
    ///   - accessory: ViewBuilder providing header accessory controls.
    ///   - content: ViewBuilder providing the primary panel content.
    public init(
        title: String,
        subtitle: String? = nil,
        style: HeaderStyle = .thick(),
        horizontalSizing: DimensionSizing = .fillParent,
        verticalSizing: DimensionSizing = .fillParent,
        isMaximized: Bool = false,
        onMaximize: (@MainActor @Sendable () -> Void)? = nil,
        onClose: (@MainActor @Sendable () -> Void)? = nil,
        backgroundColor: Color = Color(white: 0.12),
        borderColor: Color = Color(white: 0.20),
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.headerTitle = title
        self.headerSubtitle = subtitle
        self.headerStyle = style
        self.horizontalSizing = horizontalSizing
        self.verticalSizing = verticalSizing
        self.isMaximized = isMaximized
        self.onMaximize = onMaximize
        self.onClose = onClose
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.accessory = accessory()
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !headerStyle.isHidden {
                PanelHeader(
                    title: headerTitle,
                    subtitle: headerSubtitle,
                    style: headerStyle,
                    isMaximized: isMaximized,
                    onMaximize: onMaximize,
                    onClose: onClose,
                    accessory: { accessory }
                )
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .stroke(borderColor, lineWidth: 1)
        )
        .modifier(PanelFrameModifier(horizontalSizing: horizontalSizing, verticalSizing: verticalSizing))
    }
}

public extension Panel where Accessory == EmptyView {
    /// Convenience initializer for a `Panel` without accessory controls.
    init(
        title: String,
        subtitle: String? = nil,
        style: HeaderStyle = .thick(),
        horizontalSizing: DimensionSizing = .fillParent,
        verticalSizing: DimensionSizing = .fillParent,
        isMaximized: Bool = false,
        onMaximize: (@MainActor @Sendable () -> Void)? = nil,
        onClose: (@MainActor @Sendable () -> Void)? = nil,
        backgroundColor: Color = Color(white: 0.12),
        borderColor: Color = Color(white: 0.20),
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            style: style,
            horizontalSizing: horizontalSizing,
            verticalSizing: verticalSizing,
            isMaximized: isMaximized,
            onMaximize: onMaximize,
            onClose: onClose,
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            accessory: { EmptyView() },
            content: content
        )
    }
}

// MARK: - Internal Layout Frame Modifier

private struct PanelFrameModifier: ViewModifier {
    let horizontalSizing: DimensionSizing
    let verticalSizing: DimensionSizing

    func body(content: Content) -> some View {
        let (minWidth, maxWidth) = resolveBounds(for: horizontalSizing)
        let (minHeight, maxHeight) = resolveBounds(for: verticalSizing)

        content
            .frame(
                minWidth: minWidth,
                maxWidth: maxWidth,
                minHeight: minHeight,
                maxHeight: maxHeight
            )
    }

    private func resolveBounds(for sizing: DimensionSizing) -> (CGFloat?, CGFloat?) {
        switch sizing {
        case .fillParent:
            return (nil, .infinity)
        case .resizable(let min, let max, _):
            return (min, max)
        case .fixed(let size):
            return (size, size)
        case .proportional:
            return (nil, .infinity)
        }
    }
}

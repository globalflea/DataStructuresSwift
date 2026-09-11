//
// MeridianToolbar.swift
// MeridianUI
//
// Reusable, configurable toolbar container supporting horizontal and vertical orientations,
// glassmorphic styling, item selection states, and flyout popover anchors.
//

import SwiftUI

/// Orientation layout for a `MeridianToolbar`.
public enum MeridianToolbarOrientation: Sendable {
    case horizontal
    case vertical
}

/// Aesthetic styling preset for `MeridianToolbar`.
public enum MeridianToolbarStyle: Sendable {
    case glassmorphic
    case opaquePanel
    case borderless
}

/// A configurable, generic toolbar supporting both vertical and horizontal layouts.
///
/// Designed to host tools, action buttons, mode switches, and flyout menu triggers
/// without any domain-specific coupling.
public struct MeridianToolbar<Content: View>: View {
    public let orientation: MeridianToolbarOrientation
    public let style: MeridianToolbarStyle
    public let spacing: CGFloat
    public let content: Content

    /// Initializes a generic `MeridianToolbar`.
    ///
    /// - Parameters:
    ///   - orientation: Whether the toolbar flows `.horizontal` or `.vertical`.
    ///   - style: The visual background styling (`.glassmorphic`, `.opaquePanel`, `.borderless`).
    ///   - spacing: The spacing between toolbar items (default is 4pt).
    ///   - content: ViewBuilder containing the toolbar items.
    public init(
        orientation: MeridianToolbarOrientation = .vertical,
        style: MeridianToolbarStyle = .glassmorphic,
        spacing: CGFloat = 4,
        @ViewBuilder content: () -> Content
    ) {
        self.orientation = orientation
        self.style = style
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        Group {
            switch orientation {
            case .horizontal:
                HStack(spacing: spacing) {
                    content
                }
                .padding(6)
            case .vertical:
                VStack(spacing: spacing) {
                    content
                }
                .padding(6)
            }
        }
        .background(toolbarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var toolbarBackground: some View {
        switch style {
        case .glassmorphic:
            Color.black.opacity(0.65)
                .background(.ultraThinMaterial)
        case .opaquePanel:
            Color(nsColorOrUIColor: 0x1E222D)
        case .borderless:
            Color.clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .glassmorphic:
            return Color.white.opacity(0.12)
        case .opaquePanel:
            return Color.white.opacity(0.08)
        case .borderless:
            return Color.clear
        }
    }
}

/// A generic action button or toggle item designed to sit inside a `MeridianToolbar`.
public struct MeridianToolbarButton: View {
    public let iconSystemName: String?
    public let title: String?
    public let tooltip: String?
    public let isSelected: Bool
    public let hasSubmenu: Bool
    public let action: @MainActor () -> Void

    @State private var isHovering: Bool = false

    /// Initializes a toolbar item.
    ///
    /// - Parameters:
    ///   - iconSystemName: SF Symbol name (optional if title is provided).
    ///   - title: Text label (optional if icon is provided).
    ///   - tooltip: Tooltip description displayed on hover.
    ///   - isSelected: Whether the tool is currently active/selected.
    ///   - hasSubmenu: Whether to render a subtle indicator chevron for sub-menus.
    ///   - action: Closure executed on click.
    public init(
        iconSystemName: String? = nil,
        title: String? = nil,
        tooltip: String? = nil,
        isSelected: Bool = false,
        hasSubmenu: Bool = false,
        action: @escaping @MainActor () -> Void
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.tooltip = tooltip
        self.isSelected = isSelected
        self.hasSubmenu = hasSubmenu
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = iconSystemName {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                }
                if let title = title {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                }
                if hasSubmenu {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.6)
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(backgroundHighlight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip ?? title ?? "")
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var foregroundColor: Color {
        if isSelected {
            return Color.blue
        } else if isHovering {
            return Color.white
        } else {
            return Color.white.opacity(0.7)
        }
    }

    private var backgroundHighlight: Color {
        if isSelected {
            return Color.blue.opacity(0.18)
        } else if isHovering {
            return Color.white.opacity(0.08)
        } else {
            return Color.clear
        }
    }
}

/// A subtle visual separator line between groups of items in a `MeridianToolbar`.
public struct MeridianToolbarDivider: View {
    public let orientation: MeridianToolbarOrientation

    public init(orientation: MeridianToolbarOrientation = .vertical) {
        self.orientation = orientation
    }

    public var body: some View {
        Group {
            switch orientation {
            case .horizontal:
                Divider()
                    .frame(height: 18)
                    .background(Color.white.opacity(0.12))
            case .vertical:
                Divider()
                    .frame(width: 18)
                    .background(Color.white.opacity(0.12))
            }
        }
    }
}

// MARK: - Cross-Platform Color Helper
extension Color {
    init(nsColorOrUIColor hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

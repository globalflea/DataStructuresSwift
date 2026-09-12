//
// PanelHeader.swift
// MeridianUI
//
// Universal configurable header for panels, subpanes, and analytical widgets.
// Supports thick title bars with custom background/title colors, minimalist watermark
// text, and hidden modes.
//

import SwiftUI

/// Display style and appearance mode for a `PanelHeader`.
public enum HeaderStyle: Sendable, Equatable {
    /// Full-width structured title bar with configurable background and foreground colors.
    case thick(backgroundColor: Color = Color(white: 0.16), titleColor: Color = .white)

    /// Minimalist watermark text rendered directly over the content without a solid bar.
    case minimalist(color: Color = Color(white: 0.6), opacity: Double = 0.6)

    /// Suppresses header rendering entirely.
    case hidden

    /// Indicates whether the header renders in thick mode.
    public var isThick: Bool {
        if case .thick = self { return true }
        return false
    }

    /// Indicates whether the header renders in minimalist mode.
    public var isMinimalist: Bool {
        if case .minimalist = self { return true }
        return false
    }

    /// Indicates whether the header is hidden.
    public var isHidden: Bool {
        if case .hidden = self { return true }
        return false
    }
}

/// A configurable panel title bar supporting thick, minimalist watermark, and hidden modes.
///
/// Designed to host titles, status badges, contextual accessory views (such as dropdown pickers),
/// and window control buttons (maximize, close) without any domain coupling.
public struct PanelHeader<Accessory: View>: View {
    public let title: String
    public let subtitle: String?
    public let style: HeaderStyle
    public let isMaximized: Bool
    public let onMaximize: (@MainActor @Sendable () -> Void)?
    public let onClose: (@MainActor @Sendable () -> Void)?
    public let accessory: Accessory

    @State private var isMaximizeHovered: Bool = false
    @State private var isCloseHovered: Bool = false

    /// Initializes a generic `PanelHeader`.
    ///
    /// - Parameters:
    ///   - title: Primary panel title text.
    ///   - subtitle: Optional secondary label or status badge.
    ///   - style: The visual presentation mode (`.thick`, `.minimalist`, `.hidden`).
    ///   - isMaximized: Whether the parent panel is currently maximized.
    ///   - onMaximize: Optional callback when the maximize/restore button is triggered.
    ///   - onClose: Optional callback when the close button is triggered.
    ///   - accessory: ViewBuilder providing trailing action controls or dropdowns.
    public init(
        title: String,
        subtitle: String? = nil,
        style: HeaderStyle = .thick(),
        isMaximized: Bool = false,
        onMaximize: (@MainActor @Sendable () -> Void)? = nil,
        onClose: (@MainActor @Sendable () -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.isMaximized = isMaximized
        self.onMaximize = onMaximize
        self.onClose = onClose
        self.accessory = accessory()
    }

    public var body: some View {
        switch style {
        case .thick(let backgroundColor, let titleColor):
            thickHeader(backgroundColor: backgroundColor, titleColor: titleColor)
        case .minimalist(let color, let opacity):
            minimalistHeader(color: color, opacity: opacity)
        case .hidden:
            EmptyView()
        }
    }

    // MARK: - Thick Header Style

    private func thickHeader(backgroundColor: Color, titleColor: Color) -> some View {
        HStack(spacing: 8) {
            // Title & Subtitle
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(titleColor.opacity(0.65))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Accessory view slot
            accessory

            // Window controls (Maximize & Close)
            HStack(spacing: 4) {
                if let onMaximize {
                    Button(action: onMaximize) {
                        Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(isMaximizeHovered ? titleColor : titleColor.opacity(0.5))
                            .frame(width: 18, height: 18)
                            .background(isMaximizeHovered ? Color.white.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                    .onHover { isMaximizeHovered = $0 }
                    .help(isMaximized ? "Restore panel" : "Maximize panel")
                }

                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(isCloseHovered ? .red : titleColor.opacity(0.5))
                            .frame(width: 18, height: 18)
                            .background(isCloseHovered ? Color.red.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                    .onHover { isCloseHovered = $0 }
                    .help("Close panel")
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.08)),
            alignment: .bottom
        )
    }

    // MARK: - Minimalist Header Style

    private func minimalistHeader(color: Color, opacity: Double) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color.opacity(opacity))

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(color.opacity(opacity * 0.75))
            }

            Spacer(minLength: 4)

            accessory
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

public extension PanelHeader where Accessory == EmptyView {
    /// Convenience initializer without accessory content.
    init(
        title: String,
        subtitle: String? = nil,
        style: HeaderStyle = .thick(),
        isMaximized: Bool = false,
        onMaximize: (@MainActor @Sendable () -> Void)? = nil,
        onClose: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            style: style,
            isMaximized: isMaximized,
            onMaximize: onMaximize,
            onClose: onClose,
            accessory: { EmptyView() }
        )
    }
}

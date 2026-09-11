//
// MeridianMenuBar.swift
// MeridianUI
//
// A macOS-style menu bar overlay with nested dropdown support,
// keyboard shortcut badges, and clean hover highlights.
//

import SwiftUI

/// An individual action or submenu entry in a `MeridianMenu`.
public struct MeridianMenuItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let iconSystemName: String?
    public let shortcut: String?
    public let isEnabled: Bool
    public let isDestructive: Bool
    public let isSeparator: Bool
    public let subitems: [MeridianMenuItem]
    public let action: (@Sendable @MainActor () -> Void)?

    /// Standard menu item action.
    public init(
        id: UUID = UUID(),
        title: String,
        iconSystemName: String? = nil,
        shortcut: String? = nil,
        isEnabled: Bool = true,
        isDestructive: Bool = false,
        subitems: [MeridianMenuItem] = [],
        action: (@Sendable @MainActor () -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.iconSystemName = iconSystemName
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.isSeparator = false
        self.subitems = subitems
        self.action = action
    }

    /// Creates a visual divider between menu items.
    public static func separator() -> MeridianMenuItem {
        MeridianMenuItem(
            id: UUID(),
            title: "",
            isEnabled: false,
            isSeparator: true,
            action: nil
        )
    }

    private init(id: UUID, title: String, isEnabled: Bool, isSeparator: Bool, action: (@Sendable @MainActor () -> Void)?) {
        self.id = id
        self.title = title
        self.iconSystemName = nil
        self.shortcut = nil
        self.isEnabled = isEnabled
        self.isDestructive = false
        self.isSeparator = isSeparator
        self.subitems = []
        self.action = action
    }
}

/// A top-level menu category (e.g., "File", "View", "Strategy").
public struct MeridianMenuCategory: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let items: [MeridianMenuItem]

    public init(id: String = UUID().uuidString, title: String, items: [MeridianMenuItem]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

/// A macOS-style declarative menu bar overlay component.
public struct MeridianMenuBar: View {
    public let categories: [MeridianMenuCategory]
    @State private var activeCategoryID: String? = nil

    public init(categories: [MeridianMenuCategory]) {
        self.categories = categories
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(categories) { category in
                menuTopButton(for: category)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color.black.opacity(0.85))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func menuTopButton(for category: MeridianMenuCategory) -> some View {
        let isExpanded = activeCategoryID == category.id

        Button {
            if activeCategoryID == category.id {
                activeCategoryID = nil
            } else {
                activeCategoryID = category.id
            }
        } label: {
            Text(category.title)
                .font(.system(size: 12, weight: isExpanded ? .semibold : .regular))
                .foregroundColor(isExpanded ? .white : .white.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isExpanded ? Color.white.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: Binding(
                get: { activeCategoryID == category.id },
                set: { if !$0 { activeCategoryID = nil } }
            ),
            arrowEdge: .bottom
        ) {
            MeridianDropdownView(items: category.items) {
                activeCategoryID = nil
            }
        }
    }
}

/// A floating dropdown panel presenting `MeridianMenuItem` entries.
public struct MeridianDropdownView: View {
    public let items: [MeridianMenuItem]
    public let onDismiss: @MainActor () -> Void

    public init(items: [MeridianMenuItem], onDismiss: @escaping @MainActor () -> Void) {
        self.items = items
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(items) { item in
                if item.isSeparator {
                    Divider()
                        .background(Color.white.opacity(0.12))
                        .padding(.vertical, 3)
                } else {
                    MeridianDropdownRow(item: item, onDismiss: onDismiss)
                }
            }
        }
        .padding(4)
        .frame(minWidth: 180)
        .background(Color.black.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

/// Single row item within a dropdown menu.
public struct MeridianDropdownRow: View {
    public let item: MeridianMenuItem
    public let onDismiss: @MainActor () -> Void

    @State private var isHovering: Bool = false
    @State private var isSubmenuPresented: Bool = false

    public init(item: MeridianMenuItem, onDismiss: @escaping @MainActor () -> Void) {
        self.item = item
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Button {
            if !item.subitems.isEmpty {
                isSubmenuPresented.toggle()
            } else if item.isEnabled {
                onDismiss()
                item.action?()
            }
        } label: {
            HStack(spacing: 8) {
                if let icon = item.iconSystemName {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .frame(width: 14)
                }
                
                Text(item.title)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
                
                Spacer()

                if let shortcut = item.shortcut {
                    Text(shortcut)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.4))
                }

                if !item.subitems.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isHovering && item.isEnabled ? Color.blue : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .onHover { hovering in
            if item.isEnabled {
                isHovering = hovering
            }
        }
        .popover(isPresented: $isSubmenuPresented, arrowEdge: .trailing) {
            MeridianDropdownView(items: item.subitems, onDismiss: onDismiss)
        }
    }

    private var textColor: Color {
        if !item.isEnabled {
            return Color.white.opacity(0.3)
        } else if item.isDestructive {
            return Color.red
        } else {
            return Color.white
        }
    }
}

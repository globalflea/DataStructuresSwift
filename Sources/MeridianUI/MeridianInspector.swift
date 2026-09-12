//
// MeridianInspector.swift
// MeridianUI
//
// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0
//
// A dockable, resizable sidebar inspector panel and native macOS inspector modifier
// with tabbed navigation, collapsibility, and smooth width drag resizing.
//

import SwiftUI

/// Definition for an individual tab within a `MeridianInspector`.
public struct MeridianInspectorTab: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let iconSystemName: String
    public let badgeCount: Int?

    public init(id: String, title: String, iconSystemName: String, badgeCount: Int? = nil) {
        self.id = id
        self.title = title
        self.iconSystemName = iconSystemName
        self.badgeCount = badgeCount
    }
}

/// Placement edge for a `MeridianInspector`.
public enum MeridianInspectorEdge: Sendable {
    case leading
    case trailing
}

/// Tab bar header component for inspector panels.
public struct MeridianInspectorTabBar: View {
    public let tabs: [MeridianInspectorTab]
    @Binding public var selectedTabID: String
    public var onToggleCollapse: (() -> Void)? = nil
    public var edge: MeridianInspectorEdge = .trailing

    public init(
        tabs: [MeridianInspectorTab],
        selectedTabID: Binding<String>,
        onToggleCollapse: (() -> Void)? = nil,
        edge: MeridianInspectorEdge = .trailing
    ) {
        self.tabs = tabs
        self._selectedTabID = selectedTabID
        self.onToggleCollapse = onToggleCollapse
        self.edge = edge
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let isSelected = selectedTabID == tab.id
                Button {
                    selectedTabID = tab.id
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.iconSystemName)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))

                        Text(tab.title)
                            .font(.caption2.weight(isSelected ? .bold : .medium))
                    }
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(isSelected ? Color.primary.opacity(0.06) : Color.clear)
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(isSelected ? .accentColor : Color.clear),
                        alignment: .bottom
                    )
                }
                .buttonStyle(.plain)
            }

            if let onToggle = onToggleCollapse {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: edge == .trailing ? "sidebar.right" : "sidebar.left")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 42)
                }
                .buttonStyle(.plain)
                .help("Toggle Inspector")
            }
        }
        .background(.bar)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.primary.opacity(0.08)),
            alignment: .bottom
        )
    }
}

/// A dockable, interactive, resizable inspector panel component.
///
/// Supports multi-tab headers, dynamic resizing via drag handle, and animated
/// expansion/collapse using native system vibrancy materials.
public struct MeridianInspector<Content: View>: View {
    public let tabs: [MeridianInspectorTab]
    @Binding public var selectedTabID: String
    @Binding public var isCollapsed: Bool
    @Binding public var width: CGFloat
    public let minWidth: CGFloat
    public let maxWidth: CGFloat
    public let edge: MeridianInspectorEdge
    public let showsCollapseButton: Bool
    public let content: (String) -> Content

    @State private var isDraggingResizer: Bool = false
    @State private var dragInitialWidth: CGFloat = 0

    /// Initializes a `MeridianInspector`.
    ///
    /// - Parameters:
    ///   - tabs: List of tabs to display in the header bar.
    ///   - selectedTabID: Binding to the currently selected tab identifier.
    ///   - isCollapsed: Binding to whether the inspector is collapsed.
    ///   - width: Binding to the current panel width.
    ///   - minWidth: Minimum allowed panel width (default 240pt).
    ///   - maxWidth: Maximum allowed panel width (default 600pt).
    ///   - edge: Whether the panel docks on the `.trailing` (right) or `.leading` (left) edge.
    ///   - showsCollapseButton: Whether to display a collapse button inside the inspector header bar (default `false`).
    ///   - content: ViewBuilder that returns the body for the currently selected tab ID.
    public init(
        tabs: [MeridianInspectorTab],
        selectedTabID: Binding<String>,
        isCollapsed: Binding<Bool>,
        width: Binding<CGFloat>,
        minWidth: CGFloat = 240,
        maxWidth: CGFloat = 600,
        edge: MeridianInspectorEdge = .trailing,
        showsCollapseButton: Bool = false,
        @ViewBuilder content: @escaping (String) -> Content
    ) {
        self.tabs = tabs
        self._selectedTabID = selectedTabID
        self._isCollapsed = isCollapsed
        self._width = width
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.edge = edge
        self.showsCollapseButton = showsCollapseButton
        self.content = content
    }

    public var body: some View {
        HStack(spacing: 0) {
            if edge == .trailing {
                resizeHandle
            }

            if !isCollapsed {
                VStack(spacing: 0) {
                    MeridianInspectorTabBar(
                        tabs: tabs,
                        selectedTabID: $selectedTabID,
                        onToggleCollapse: showsCollapseButton ? {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isCollapsed.toggle()
                            }
                        } : nil,
                        edge: edge
                    )

                    content(selectedTabID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: width)
                .background(.regularMaterial)
            }

            if edge == .leading {
                resizeHandle
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isCollapsed)
    }

    // MARK: - Resize Handle
    private var resizeHandle: some View {
        Rectangle()
            .frame(width: 4)
            .foregroundColor(isDraggingResizer ? Color.accentColor : Color.primary.opacity(0.08))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isDraggingResizer {
                            isDraggingResizer = true
                            dragInitialWidth = width
                        }
                        let delta = edge == .trailing ? -value.translation.width : value.translation.width
                        let newWidth = max(minWidth, min(maxWidth, dragInitialWidth + delta))
                        width = newWidth
                    }
                    .onEnded { _ in
                        isDraggingResizer = false
                    }
            )
    }
}

// MARK: - Native Window Inspector Extension

public extension View {
    /// Mounts a native macOS inspector panel hosting tabbed navigation.
    func meridianInspector<InspectorContent: View>(
        isPresented: Binding<Bool>,
        tabs: [MeridianInspectorTab],
        selectedTabID: Binding<String>,
        @ViewBuilder content: @escaping (String) -> InspectorContent
    ) -> some View {
        self.inspector(isPresented: isPresented) {
            VStack(spacing: 0) {
                MeridianInspectorTabBar(tabs: tabs, selectedTabID: selectedTabID)
                content(selectedTabID.wrappedValue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(.regularMaterial)
        }
    }
}

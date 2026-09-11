//
// MeridianInspector.swift
// MeridianUI
//
// A dockable, resizable sidebar inspector panel with tabbed navigation,
// collapsibility, and smooth width drag resizing.
//

import SwiftUI

/// Definition for an individual tab within a `MeridianInspector`.
public struct MeridianInspectorTab: Identifiable, Sendable {
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

/// A dockable, interactive, resizable inspector panel component.
///
/// Supports multi-tab headers, dynamic resizing via drag handle, and animated
/// expansion/collapse.
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
                    // Inspector Header / Tab Bar
                    headerBar

                    // Selected Tab View
                    content(selectedTabID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(width: width)
                .background(Color(nsColorOrUIColor: 0x1E222D))
            }

            if edge == .leading {
                resizeHandle
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isCollapsed)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let isSelected = selectedTabID == tab.id
                Button {
                    selectedTabID = tab.id
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.iconSystemName)
                            .font(.system(size: 11))
                        Text(tab.title)
                            .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundColor(isSelected ? Color.blue : Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(isSelected ? Color.blue : Color.clear),
                        alignment: .bottom
                    )
                }
                .buttonStyle(.plain)
            }

            if showsCollapseButton {
                // Optional collapse button (omitted by default when main app navigation provides the toggle)
                Button {
                    withAnimation {
                        isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: edge == .trailing ? "sidebar.right" : "sidebar.left")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .help(isCollapsed ? "Expand Inspector" : "Collapse Inspector")
            }
        }
        .background(Color(nsColorOrUIColor: 0x181B22))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }

    // MARK: - Resize Handle
    private var resizeHandle: some View {
        Rectangle()
            .frame(width: 4)
            .foregroundColor(isDraggingResizer ? Color.blue : Color.white.opacity(0.08))
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

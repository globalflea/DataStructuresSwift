//
// MeridianGlassCard.swift
// MeridianCore
//
// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0
//
// Reusable glassmorphic HUD card, pill, and floating control bar containers
// adhering to Apple Human Interface Guidelines (HIG) with dynamic system materials.
//

import SwiftUI

/// Preset corner radius styles for `MeridianGlassCard`.
public enum MeridianGlassCornerStyle: Sendable {
    case rounded(CGFloat)
    case capsule
    case continuous(CGFloat)

    public var cornerRadius: CGFloat {
        switch self {
        case .rounded(let radius): return radius
        case .capsule: return 9999
        case .continuous(let radius): return radius
        }
    }
}

/// A floating, translucent card container adhering to macOS Human Interface Guidelines (HIG).
///
/// Features dynamic `.ultraThinMaterial` or `.regularMaterial` backgrounds, subtle adaptive borders,
/// and dual ambient/key-light drop shadows for high visual depth.
public struct MeridianGlassCard<Content: View>: View {
    public let cornerStyle: MeridianGlassCornerStyle
    public let material: Material
    public let padding: EdgeInsets
    public let content: Content

    /// Creates a glass card container.
    ///
    /// - Parameters:
    ///   - cornerStyle: Corner shape style (default: `.rounded(12)`).
    ///   - material: System vibrancy material (default: `.ultraThinMaterial`).
    ///   - padding: Internal padding applied to the content (default: 12pt on all sides).
    ///   - content: ViewBuilder for the card contents.
    public init(
        cornerStyle: MeridianGlassCornerStyle = .rounded(12),
        material: Material = .ultraThinMaterial,
        padding: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerStyle = cornerStyle
        self.material = material
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(material)
            .clipShape(cardShape)
            .overlay(
                cardShape
                    .stroke(borderStrokeColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 7)
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    private var cardShape: AnyShape {
        switch cornerStyle {
        case .capsule:
            return AnyShape(Capsule())
        case .rounded(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .circular))
        case .continuous(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }

    private var borderStrokeColor: Color {
        Color.white.opacity(0.14)
    }
}

/// A compact glass pill HUD component, ideal for status indicators and micro-metrics.
public struct MeridianGlassPill<Content: View>: View {
    public let material: Material
    public let content: Content

    public init(
        material: Material = .ultraThinMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.material = material
        self.content = content()
    }

    public var body: some View {
        MeridianGlassCard(
            cornerStyle: .capsule,
            material: material,
            padding: EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        ) {
            content
        }
    }
}

/// A floating glass capsule control bar for map/canvas overlay toolbars.
public struct MeridianGlassControlBar<Content: View>: View {
    public let spacing: CGFloat
    public let content: Content

    public init(
        spacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        MeridianGlassCard(
            cornerStyle: .capsule,
            material: .ultraThinMaterial,
            padding: EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        ) {
            HStack(spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - View Modifiers

public extension View {
    /// Wraps the view in a floating `MeridianGlassCard`.
    func meridianGlassCard(
        cornerRadius: CGFloat = 12,
        material: Material = .ultraThinMaterial,
        padding: CGFloat = 12
    ) -> some View {
        MeridianGlassCard(
            cornerStyle: .continuous(cornerRadius),
            material: material,
            padding: EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding)
        ) {
            self
        }
    }

    /// Wraps the view in a capsule `MeridianGlassPill`.
    func meridianGlassPill(
        material: Material = .ultraThinMaterial
    ) -> some View {
        MeridianGlassPill(material: material) {
            self
        }
    }
}

//
// DirectManipulationCanvas.swift
// MeridianCore
//
// Copyright (c) 2026 the Meridian project authors
// Licensed under Apache License v2.0
//
// Reusable direct-manipulation 2D canvas viewport supporting 1:1 pan offset accumulation,
// trackpad pinch-to-zoom, spring reset, and macOS cursor state management.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Configuration options for `DirectManipulationCanvas`.
public struct CanvasManipulationConfig: Sendable {
    public var minScale: CGFloat
    public var maxScale: CGFloat
    public var springResponse: Double
    public var dampingFraction: Double

    public init(
        minScale: CGFloat = 0.15,
        maxScale: CGFloat = 6.0,
        springResponse: Double = 0.35,
        dampingFraction: Double = 0.8
    ) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.springResponse = springResponse
        self.dampingFraction = dampingFraction
    }

    public static let `default` = CanvasManipulationConfig()
}

/// A 2D viewport container enabling fluid, 1:1 direct manipulation panning and pinch-to-zoom.
///
/// Designed to eliminate gesture scaling jumps, runaway integration velocity, and jitter.
/// Conforms to macOS Human Interface Guidelines (HIG) with smooth spring transitions and cursor feedback.
public struct DirectManipulationCanvas<Content: View>: View {
    @Binding public var offset: CGSize
    @Binding public var scale: CGFloat
    public let config: CanvasManipulationConfig
    public let content: Content

    @GestureState private var gestureDragTranslation: CGSize = .zero
    @GestureState private var gestureMagnification: CGFloat = 1.0
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false

    /// Creates a direct-manipulation canvas container with external bindings.
    ///
    /// - Parameters:
    ///   - offset: Binding to current pan translation.
    ///   - scale: Binding to current zoom scale factor.
    ///   - config: Manipulation constraints and spring settings.
    ///   - content: ViewBuilder for canvas children.
    public init(
        offset: Binding<CGSize>,
        scale: Binding<CGFloat>,
        config: CanvasManipulationConfig = .default,
        @ViewBuilder content: () -> Content
    ) {
        self._offset = offset
        self._scale = scale
        self.config = config
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            let currentScale = clampedScale(scale * gestureMagnification)
            let currentOffset = CGSize(
                width: offset.width + gestureDragTranslation.width,
                height: offset.height + gestureDragTranslation.height
            )

            ZStack {
                // Invisible hit-test backing layer
                Color.clear
                    .contentShape(Rectangle())

                // Transformable content
                content
                    .scaleEffect(currentScale)
                    .offset(currentOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .gesture(panGesture)
            .simultaneousGesture(magnificationGesture)
            #if os(macOS)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovering = true
                    updateCursor()
                case .ended:
                    isHovering = false
                    resetCursor()
                }
            }
            #endif
        }
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($gestureDragTranslation) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                if !isDragging {
                    isDragging = true
                    #if os(macOS)
                    updateCursor()
                    #endif
                }
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
                isDragging = false
                #if os(macOS)
                updateCursor()
                #endif
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureMagnification) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let targetScale = clampedScale(scale * value)
                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                    scale = targetScale
                }
            }
    }

    // MARK: - Helpers

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        max(config.minScale, min(config.maxScale, value))
    }

    /// Resets pan offset to center and zoom scale to 1.0 with a smooth spring animation.
    public func resetToCenter(animated: Bool = true) {
        if animated {
            withAnimation(.spring(response: config.springResponse, dampingFraction: config.dampingFraction)) {
                offset = .zero
                scale = 1.0
            }
        } else {
            offset = .zero
            scale = 1.0
        }
    }

    #if os(macOS)
    private func updateCursor() {
        if isDragging {
            NSCursor.closedHand.set()
        } else if isHovering {
            NSCursor.openHand.set()
        }
    }

    private func resetCursor() {
        NSCursor.arrow.set()
    }
    #endif
}

// MARK: - View Modifier

public struct DirectManipulationCanvasModifier: ViewModifier {
    @Binding public var offset: CGSize
    @Binding public var scale: CGFloat
    public let config: CanvasManipulationConfig

    public init(
        offset: Binding<CGSize>,
        scale: Binding<CGFloat>,
        config: CanvasManipulationConfig = .default
    ) {
        self._offset = offset
        self._scale = scale
        self.config = config
    }

    public func body(content: Content) -> some View {
        DirectManipulationCanvas(
            offset: $offset,
            scale: $scale,
            config: config
        ) {
            content
        }
    }
}

public extension View {
    /// Envelops the view in a 1:1 direct manipulation canvas pan and zoom container.
    func directManipulationCanvas(
        offset: Binding<CGSize>,
        scale: Binding<CGFloat>,
        config: CanvasManipulationConfig = .default
    ) -> some View {
        modifier(DirectManipulationCanvasModifier(offset: offset, scale: scale, config: config))
    }
}

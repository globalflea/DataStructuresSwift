//
// MeridianPopup.swift
// MeridianUI
//
// Reusable, animated draggable modal dialog host and floating popup container.
// Decoupled from application domain logic to allow clean inspection of underlying viewports.
//

import SwiftUI

/// A floating, draggable modal dialog host allowing users to freely reposition
/// modal windows across the screen to view underlying content.
public struct MeridianPopup<Content: View>: View {
    public let title: String?
    public let targetWidth: CGFloat
    @Binding public var isPresented: Bool
    public let onDismiss: (@MainActor () -> Void)?
    public let content: Content

    @State private var offset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero
    @State private var isHoveringClose: Bool = false

    /// Initializes a draggable `MeridianPopup`.
    ///
    /// - Parameters:
    ///   - title: Optional header title displayed in the drag handle bar.
    ///   - targetWidth: Intended width for the dialog card (default 520pt).
    ///   - isPresented: Binding controlling the presentation state.
    ///   - onDismiss: Optional callback invoked when dismissed.
    ///   - content: ViewBuilder for the body of the dialog.
    public init(
        title: String? = nil,
        targetWidth: CGFloat = 520,
        isPresented: Binding<Bool>,
        onDismiss: (@MainActor () -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.targetWidth = targetWidth
        self._isPresented = isPresented
        self.onDismiss = onDismiss
        self.content = content()
    }

    public var body: some View {
        if isPresented {
            GeometryReader { geometry in
                let safeWidth = min(targetWidth, max(320, geometry.size.width - 48))

                ZStack {
                    // Subtle translucent backdrop (allows inspection of content underneath)
                    Color.black.opacity(0.15)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismiss()
                        }

                    // Floating Draggable Panel Card
                    VStack(spacing: 0) {
                        dragHeaderBar(geometry: geometry)

                        content
                    }
                    .frame(width: safeWidth)
                    .background(Color(nsColorOrUIColor: 0x1E222D))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
                    .offset(offset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    // MARK: - Header Bar & Drag Handle
    @ViewBuilder
    private func dragHeaderBar(geometry: GeometryProxy) -> some View {
        HStack(spacing: 8) {
            // Drag Indicator & Optional Title
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.4))

                if let title = title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.85))
                }
            }

            Spacer()

            // Close Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isHoveringClose ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(isHoveringClose ? Color.white.opacity(0.12) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringClose = hovering
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Color(nsColorOrUIColor: 0x181B22))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    offset = CGSize(
                        width: dragStartOffset.width + value.translation.width,
                        height: dragStartOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    // Clamp to viewport
                    let maxHorizontal = (geometry.size.width - targetWidth) / 2
                    let maxVertical = geometry.size.height / 2 - 40
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        offset.width = min(max(offset.width, -maxHorizontal), maxHorizontal)
                        offset.height = min(max(offset.height, -maxVertical), maxVertical)
                    }
                    dragStartOffset = offset
                }
        )
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.16)) {
            isPresented = false
            offset = .zero
            dragStartOffset = .zero
        }
        onDismiss?()
    }
}

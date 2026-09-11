//
// MeridianTimeline.swift
// MeridianUI
//
// A generic, zoomable, and pannable timeline scroller.
// Solves the "Weekend Gap" / market closure problem via an abstract Coordinate Mapping Protocol.
//

import SwiftUI

/// Represents a single tick mark rendered along the timeline axis.
public struct TimelineTickMark: Identifiable, Sendable {
    public let id: String
    public let coordinate: Double
    public let label: String
    public let isMajor: Bool

    public init(coordinate: Double, label: String, isMajor: Bool = false) {
        self.id = "\(coordinate)_\(label)"
        self.coordinate = coordinate
        self.label = label
        self.isMajor = isMajor
    }
}

/// Abstract Coordinate Mapping Protocol.
///
/// Decouples generic timeline rendering from specific chronological layouts.
/// Can represent continuous linear time (audio/video editing) or discontinuous
/// trading bar indices (omitting weekend gaps and overnight closures).
public protocol TimelineCoordinateMapping: Sendable {
    /// Maps an abstract chronological date to a coordinate unit (e.g. bar index or linear timestamp).
    func coordinate(for date: Date) -> Double?

    /// Maps a coordinate unit back to a calendar date.
    func date(for coordinate: Double) -> Date?

    /// Generates appropriate tick marks for a visible coordinate range.
    func tickMarks(in range: ClosedRange<Double>, maxTicks: Int) -> [TimelineTickMark]
}

/// Default linear continuous timeline mapping for non-discontinuous timelines.
public struct LinearContinuousTimelineMapping: TimelineCoordinateMapping {
    public let startDate: Date
    public let secondsPerUnit: Double

    public init(startDate: Date = Date(timeIntervalSince1970: 0), secondsPerUnit: Double = 1.0) {
        self.startDate = startDate
        self.secondsPerUnit = secondsPerUnit
    }

    public func coordinate(for date: Date) -> Double? {
        date.timeIntervalSince(startDate) / secondsPerUnit
    }

    public func date(for coordinate: Double) -> Date? {
        startDate.addingTimeInterval(coordinate * secondsPerUnit)
    }

    public func tickMarks(in range: ClosedRange<Double>, maxTicks: Int) -> [TimelineTickMark] {
        guard maxTicks > 1, range.upperBound > range.lowerBound else { return [] }
        let span = range.upperBound - range.lowerBound
        let step = span / Double(maxTicks)
        var ticks: [TimelineTickMark] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        for i in 0..<maxTicks {
            let coord = range.lowerBound + Double(i) * step
            if let d = date(for: coord) {
                ticks.append(TimelineTickMark(coordinate: coord, label: formatter.string(from: d)))
            }
        }
        return ticks
    }
}

/// A generic, configurable timeline control component.
public struct MeridianTimeline<Mapping: TimelineCoordinateMapping>: View {
    @Binding public var visibleRange: ClosedRange<Double>
    public let mapping: Mapping
    public let rangePresets: [String]
    public let onSelectPreset: ((String) -> Void)?
    public let onScrub: ((Double) -> Void)?

    @State private var isDraggingTimeline: Bool = false
    @State private var dragInitialRange: ClosedRange<Double>?

    /// Initializes a `MeridianTimeline`.
    ///
    /// - Parameters:
    ///   - visibleRange: Binding to the active coordinate range (e.g. 0...100).
    ///   - mapping: An implementation of `TimelineCoordinateMapping`.
    ///   - rangePresets: Quick selection labels (e.g. ["1D", "1W", "1M", "1Y", "ALL"]).
    ///   - onSelectPreset: Callback when a preset is chosen.
    ///   - onScrub: Callback when the user scrubs or jumps to a coordinate.
    public init(
        visibleRange: Binding<ClosedRange<Double>>,
        mapping: Mapping,
        rangePresets: [String] = [],
        onSelectPreset: ((String) -> Void)? = nil,
        onScrub: ((Double) -> Void)? = nil
    ) {
        self._visibleRange = visibleRange
        self.mapping = mapping
        self.rangePresets = rangePresets
        self.onSelectPreset = onSelectPreset
        self.onScrub = onScrub
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Preset Pills
            if !rangePresets.isEmpty {
                HStack(spacing: 2) {
                    ForEach(rangePresets, id: \.self) { preset in
                        Button {
                            onSelectPreset?(preset)
                        } label: {
                            Text(preset)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.75))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 6)
            }

            // Interactive Axis Scrubber Canvas
            GeometryReader { geometry in
                let ticks = mapping.tickMarks(in: visibleRange, maxTicks: Int(geometry.size.width / 80))

                ZStack(alignment: .bottomLeading) {
                    // Axis Line
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.12))

                    // Tick Labels
                    ForEach(ticks) { tick in
                        let normalized = (tick.coordinate - visibleRange.lowerBound) / (visibleRange.upperBound - visibleRange.lowerBound)
                        let xPos = CGFloat(normalized) * geometry.size.width

                        VStack(spacing: 2) {
                            Rectangle()
                                .frame(width: 1, height: tick.isMajor ? 6 : 4)
                                .foregroundColor(Color.white.opacity(tick.isMajor ? 0.4 : 0.2))
                            Text(tick.label)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        .position(x: max(20, min(geometry.size.width - 20, xPos)), y: geometry.size.height / 2)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragInitialRange == nil {
                                dragInitialRange = visibleRange
                            }
                            guard let initial = dragInitialRange else { return }
                            let span = initial.upperBound - initial.lowerBound
                            let deltaUnits = -(Double(value.translation.width) / Double(geometry.size.width)) * span
                            let newLower = initial.lowerBound + deltaUnits
                            let newUpper = initial.upperBound + deltaUnits
                            visibleRange = newLower...newUpper
                        }
                        .onEnded { _ in
                            dragInitialRange = nil
                        }
                )
            }
            .frame(height: 30)

            // Zoom In / Zoom Out Quick Buttons
            HStack(spacing: 2) {
                Button {
                    zoom(by: 0.8)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.7))
                        .padding(4)
                }
                .buttonStyle(.plain)

                Button {
                    zoom(by: 1.25)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.7))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 6)
        }
        .frame(height: 32)
        .background(Color(nsColorOrUIColor: 0x181B22))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .top
        )
    }

    private func zoom(by factor: Double) {
        let center = (visibleRange.lowerBound + visibleRange.upperBound) / 2
        let halfSpan = ((visibleRange.upperBound - visibleRange.lowerBound) * factor) / 2
        visibleRange = (center - halfSpan)...(center + halfSpan)
    }
}

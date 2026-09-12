import Testing
import Foundation
import SwiftUI
@testable import MeridianUI

@Suite("MeridianUI Generic Components Suite")
struct MeridianUITests {

    @Test("MeridianToolbar button and item configurations")
    @MainActor
    func testToolbarButtonProperties() {
        var clicked = false
        let button = MeridianToolbarButton(
            iconSystemName: "line.diagonal",
            title: "Trendline",
            tooltip: "Draw a linear trendline",
            isSelected: true,
            hasSubmenu: true
        ) {
            clicked = true
        }

        #expect(button.iconSystemName == "line.diagonal")
        #expect(button.title == "Trendline")
        #expect(button.tooltip == "Draw a linear trendline")
        #expect(button.isSelected == true)
        #expect(button.hasSubmenu == true)
        #expect(clicked == false)
    }

    @Test("MeridianMenuItem hierarchy and separator creation")
    func testMenuItemProperties() {
        let child = MeridianMenuItem(title: "Save Copy", shortcut: "⌘⇧S")
        let sep = MeridianMenuItem.separator()
        let parent = MeridianMenuItem(
            title: "File",
            subitems: [child, sep]
        )

        #expect(parent.title == "File")
        #expect(parent.subitems.count == 2)
        #expect(parent.subitems[0].title == "Save Copy")
        #expect(parent.subitems[0].shortcut == "⌘⇧S")
        #expect(parent.subitems[1].isSeparator == true)
    }

    @Test("MeridianInspectorTab properties")
    func testInspectorTab() {
        let tab = MeridianInspectorTab(
            id: "watchlist",
            title: "Watchlist",
            iconSystemName: "list.bullet",
            badgeCount: 5
        )

        #expect(tab.id == "watchlist")
        #expect(tab.title == "Watchlist")
        #expect(tab.iconSystemName == "list.bullet")
        #expect(tab.badgeCount == 5)
    }

    @Test("LinearContinuousTimelineMapping forward and inverse projection")
    func testTimelineLinearMapping() {
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        let mapping = LinearContinuousTimelineMapping(startDate: baseDate, secondsPerUnit: 60)

        // 10 units = 600 seconds
        let targetDate = baseDate.addingTimeInterval(600)
        let coord = mapping.coordinate(for: targetDate)
        #expect(coord == 10.0)

        let resolvedDate = mapping.date(for: 10.0)
        #expect(resolvedDate == targetDate)

        let ticks = mapping.tickMarks(in: 0...50, maxTicks: 5)
        #expect(ticks.count == 5)
    }

    @Test("Discontinuous Coordinate Mapping (Weekend Gap Solution)")
    func testDiscontinuousCoordinateMapping() {
        // Mock a calendar where Friday bar is coordinate 0 and Monday bar is coordinate 1 (skipping Sat & Sun)
        struct MockMarketDayMapping: TimelineCoordinateMapping {
            let tradingDates: [Date]

            func coordinate(for date: Date) -> Double? {
                tradingDates.firstIndex(of: date).map { Double($0) }
            }

            func date(for coordinate: Double) -> Date? {
                let idx = Int(coordinate.rounded())
                guard idx >= 0 && idx < tradingDates.count else { return nil }
                return tradingDates[idx]
            }

            func tickMarks(in range: ClosedRange<Double>, maxTicks: Int) -> [TimelineTickMark] {
                let start = max(0, Int(range.lowerBound))
                let end = min(tradingDates.count - 1, Int(range.upperBound))
                guard start <= end else { return [] }
                return (start...end).map { i in
                    TimelineTickMark(coordinate: Double(i), label: "Bar \(i)", isMajor: true)
                }
            }
        }

        let friday = Date(timeIntervalSince1970: 100_000)
        let monday = Date(timeIntervalSince1970: 100_000 + 86400 * 3) // 3 days later
        let marketMapping = MockMarketDayMapping(tradingDates: [friday, monday])

        // Friday is bar 0, Monday is bar 1 with zero weekend gap
        #expect(marketMapping.coordinate(for: friday) == 0.0)
        #expect(marketMapping.coordinate(for: monday) == 1.0)
        #expect(marketMapping.date(for: 1.0) == monday)

        let ticks = marketMapping.tickMarks(in: 0...1, maxTicks: 2)
        #expect(ticks.count == 2)
        #expect(ticks[0].label == "Bar 0")
        #expect(ticks[1].label == "Bar 1")
    }

    // MARK: - DimensionSizing Tests

    @Test("DimensionSizing constraints and clamping behavior")
    func testDimensionSizing() {
        // Fill Parent
        let fill = DimensionSizing.fillParent
        #expect(fill.isFillParent == true)
        #expect(fill.isResizable == false)
        #expect(fill.isFixed == false)
        #expect(fill.isProportional == false)
        #expect(fill.defaultSize == nil)
        #expect(fill.clamp(420) == 420)

        // Resizable
        let resizable = DimensionSizing.resizable(min: 100, max: 400, defaultSize: 250)
        #expect(resizable.isResizable == true)
        #expect(resizable.isFillParent == false)
        #expect(resizable.defaultSize == 250)
        #expect(resizable.clamp(50) == 100)   // Under min
        #expect(resizable.clamp(200) == 200) // Within bounds
        #expect(resizable.clamp(550) == 400) // Over max

        // Fixed
        let fixed = DimensionSizing.fixed(320)
        #expect(fixed.isFixed == true)
        #expect(fixed.isResizable == false)
        #expect(fixed.defaultSize == 320)
        #expect(fixed.clamp(10) == 320)
        #expect(fixed.clamp(9999) == 320)

        // Proportional
        let prop = DimensionSizing.proportional(0.35)
        #expect(prop.isProportional == true)
        #expect(prop.defaultSize == nil)
        #expect(prop.clamp(500) == 500)
    }

    // MARK: - Splitter Tests

    @Test("Splitter orientation and callback execution")
    @MainActor
    func testSplitterPropertiesAndCallbacks() {
        #expect(SplitterOrientation.horizontal != SplitterOrientation.vertical)

        var dragDelta: CGFloat = 0
        var resetCalled = false

        let splitter = Splitter(
            orientation: .horizontal,
            thickness: 2,
            hitArea: 10,
            onDrag: { delta in
                dragDelta += delta
            },
            onReset: {
                resetCalled = true
            }
        )

        #expect(splitter.orientation == .horizontal)
        #expect(splitter.thickness == 2)
        #expect(splitter.hitArea == 10)

        splitter.onDrag?(15.5)
        #expect(dragDelta == 15.5)

        splitter.onReset?()
        #expect(resetCalled == true)
    }

    // MARK: - ToolContainer Anchor & Chevron Tests

    @Test("ToolContainer anchor directional chevron physics")
    func testToolContainerChevronPhysics() {
        // Leading anchor:
        // Collapsed (capacity == 1): points right (>) to expand into workspace
        // Expanded (capacity > 1): points left (<) back towards anchor to collapse
        #expect(ToolbarAnchor.leading.isVertical == true)
        #expect(ToolbarAnchor.leading.chevronIcon(isExpanded: false) == "chevron.right")
        #expect(ToolbarAnchor.leading.chevronIcon(isExpanded: true) == "chevron.left")

        // Trailing anchor:
        // Collapsed: points left (<) to expand into workspace
        // Expanded: points right (>) back towards anchor to collapse
        #expect(ToolbarAnchor.trailing.isVertical == true)
        #expect(ToolbarAnchor.trailing.chevronIcon(isExpanded: false) == "chevron.left")
        #expect(ToolbarAnchor.trailing.chevronIcon(isExpanded: true) == "chevron.right")

        // Top anchor:
        // Collapsed: points down (v) to expand downward
        // Expanded: points up (^) back towards anchor to collapse
        #expect(ToolbarAnchor.top.isVertical == false)
        #expect(ToolbarAnchor.top.chevronIcon(isExpanded: false) == "chevron.down")
        #expect(ToolbarAnchor.top.chevronIcon(isExpanded: true) == "chevron.up")

        // Bottom anchor:
        // Collapsed: points up (^) to expand upward
        // Expanded: points down (v) back towards anchor to collapse
        #expect(ToolbarAnchor.bottom.isVertical == false)
        #expect(ToolbarAnchor.bottom.chevronIcon(isExpanded: false) == "chevron.up")
        #expect(ToolbarAnchor.bottom.chevronIcon(isExpanded: true) == "chevron.down")
    }

    // MARK: - PanelHeader & HeaderStyle Tests

    @Test("PanelHeader styles and callbacks")
    @MainActor
    func testPanelHeaderStyles() {
        let thick = HeaderStyle.thick(backgroundColor: .gray, titleColor: .white)
        #expect(thick.isThick == true)
        #expect(thick.isMinimalist == false)
        #expect(thick.isHidden == false)

        let min = HeaderStyle.minimalist(color: .secondary, opacity: 0.7)
        #expect(min.isThick == false)
        #expect(min.isMinimalist == true)
        #expect(min.isHidden == false)

        let hidden = HeaderStyle.hidden
        #expect(hidden.isHidden == true)
        #expect(hidden.isThick == false)
        #expect(hidden.isMinimalist == false)

        var maximized = false
        var closed = false

        let header = PanelHeader(
            title: "Options Chain",
            subtitle: "SPY",
            style: thick,
            isMaximized: false,
            onMaximize: { maximized = true },
            onClose: { closed = true }
        )

        #expect(header.title == "Options Chain")
        #expect(header.subtitle == "SPY")
        #expect(header.isMaximized == false)

        header.onMaximize?()
        #expect(maximized == true)

        header.onClose?()
        #expect(closed == true)
    }

    // MARK: - Panel Construction Tests

    @Test("Panel construction with orthogonal DimensionSizing")
    @MainActor
    func testPanelConstruction() {
        let panel = Panel(
            title: "Seasonality",
            subtitle: "Quarterly Distribution",
            style: .thick(),
            horizontalSizing: .fillParent,
            verticalSizing: .resizable(min: 150, max: 600, defaultSize: 280)
        ) {
            Text("ECharts Canvas View")
        }

        #expect(panel.headerTitle == "Seasonality")
        #expect(panel.headerSubtitle == "Quarterly Distribution")
        #expect(panel.horizontalSizing == .fillParent)
        #expect(panel.verticalSizing == .resizable(min: 150, max: 600, defaultSize: 280))
    }
}


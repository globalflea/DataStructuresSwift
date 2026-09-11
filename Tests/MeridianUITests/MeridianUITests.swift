import Testing
import Foundation
import SwiftUI
@testable import MeridianUI

@Suite("MeridianUI Generic Components Suite")
struct MeridianUITests {

    @Test("MeridianToolbar button and item configurations")
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
}

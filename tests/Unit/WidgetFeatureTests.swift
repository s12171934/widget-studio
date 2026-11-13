import AppIntents
import WidgetKit
import XCTest
@testable import WidgetStudio

final class WidgetFeatureTests: XCTestCase {
    func testOldDesignsDecodeWithNewDefaultsAndKeepImageLayouts() throws {
        let original = WidgetDesign(name: "기존 사진", template: .photo, title: "사진",
                                    imageLayouts: ["large": WidgetImageLayout(zoom: 2)])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        for key in ["checklistItems", "counterStart", "counterStep", "counterGoal", "focusMinutes"] { json.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(WidgetDesign.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.imageLayouts["large"]?.zoom, 2)
        XCTAssertEqual(decoded.focusMinutes, 25)
        XCTAssertEqual(decoded.counterStep, 1)
        XCTAssertTrue(decoded.checklistItems.isEmpty)
    }

    func testChecklistTogglesOnlyItsOwnItems() {
        let item = ChecklistItem(title: "책 읽기")
        let design = WidgetDesign(name: "목록", template: .checklist, title: "오늘", checklistItems: [item])
        var state = WidgetActivity()
        state.apply(.toggleItem, to: design, itemID: UUID())
        XCTAssertTrue(state.completedItems.isEmpty)
        state.apply(.toggleItem, to: design, itemID: item.id)
        XCTAssertEqual(state.completedItems, [item.id])
        state.apply(.toggleItem, to: design, itemID: item.id)
        XCTAssertTrue(state.completedItems.isEmpty)
    }

    func testCounterUsesConfiguredStepStartAndReset() {
        let design = WidgetDesign(name: "카운터", template: .counter, title: "횟수", counterStart: -4, counterStep: 3)
        var state = WidgetActivity()
        state.apply(.increment, to: design)
        XCTAssertEqual(state.counterValue, -1)
        state.apply(.decrement, to: design)
        XCTAssertEqual(state.counterValue, -4)
        state.apply(.resetCounter, to: design)
        XCTAssertNil(state.counterValue)
        state.apply(.toggleTimer, to: design)
        XCTAssertNil(state.timerEnd)
    }

    func testCounterOverflowDoesNotCrashOrWrap() {
        let design = WidgetDesign(name: "상한", template: .counter, title: "", counterStart: Int.max)
        var state = WidgetActivity()
        state.apply(.increment, to: design)
        XCTAssertNil(state.counterValue)
        state.apply(.decrement, to: design)
        XCTAssertEqual(state.counterValue, Int.max - 1)
    }

    func testTimerPauseResumeExpiryAndResetPreserveElapsedTime() throws {
        let start = Date(timeIntervalSince1970: 1000)
        let design = WidgetDesign(name: "집중", template: .focus, title: "집중", focusMinutes: 5)
        var state = WidgetActivity()
        state.apply(.toggleTimer, to: design, at: start)
        XCTAssertEqual(state.timerEnd, start.addingTimeInterval(300))
        state.apply(.toggleTimer, to: design, at: start.addingTimeInterval(45))
        XCTAssertNil(state.timerEnd)
        XCTAssertEqual(try XCTUnwrap(state.pausedSeconds), 255, accuracy: 0.001)
        state.apply(.toggleTimer, to: design, at: start.addingTimeInterval(100))
        XCTAssertEqual(state.timerEnd, start.addingTimeInterval(355))
        XCTAssertEqual(state.remainingSeconds(for: design, at: start.addingTimeInterval(400)), 0)
        state.apply(.toggleTimer, to: design, at: start.addingTimeInterval(400))
        XCTAssertEqual(state.timerEnd, start.addingTimeInterval(700))
        state.apply(.resetTimer, to: design)
        XCTAssertNil(state.timerEnd)
        XCTAssertEqual(state.remainingSeconds(for: design, at: start), 300)
    }

    func testWidgetIntentPersistsOutsideDesignAndIsolatesDesigns() async throws {
        let previous = DesignStore.load()
        let first = WidgetDesign(name: "독립 1", template: .counter, title: "")
        let second = WidgetDesign(name: "독립 2", template: .counter, title: "")
        defer {
            DesignStore.save(previous)
            DesignStore.deleteActivity(for: first.id)
            DesignStore.deleteActivity(for: second.id)
        }
        DesignStore.save(previous + [first, second])
        _ = try await WidgetActionIntent(designID: first.id, action: .increment).perform()
        XCTAssertEqual(DesignStore.loadActivity(for: first.id).counterValue, 1)
        XCTAssertNil(DesignStore.loadActivity(for: second.id).counterValue)
        // 위젯을 조작하기 전에 열린 편집기가 저장되어도 진행 상황을 유지한다.
        var edited = first
        edited.title = "이름 수정"
        DesignStore.save(previous + [edited, second])
        XCTAssertEqual(DesignStore.loadActivity(for: first.id).counterValue, 1)
        XCTAssertFalse(WidgetActionIntent.openAppWhenRun)
        DesignStore.save(previous)
        XCTAssertThrowsError(try DesignStore.perform(.increment, for: first.id))
    }

    func testExtraLargeImageSettingsAreIndependentAndRoundTrip() throws {
        var design = WidgetDesign(name: "사진", template: .photo, title: "")
        design.imageLayouts[WidgetFamily.systemLarge.studioSizeKey] = WidgetImageLayout(zoom: 1.5)
        design.imageLayouts[WidgetFamily.systemExtraLarge.studioSizeKey] = WidgetImageLayout(mode: .fit, zoom: 2)
        let saved = try JSONDecoder().decode(WidgetDesign.self, from: JSONEncoder().encode(design))
        XCTAssertEqual(saved.imageLayout(for: .systemLarge).zoom, 1.5)
        XCTAssertEqual(saved.imageLayout(for: .systemExtraLarge).mode, .fit)
        XCTAssertEqual(saved.imageLayout(for: .systemExtraLarge).zoom, 2)
        let size = DesignPreviewCard.size(for: .systemExtraLarge)
        XCTAssertGreaterThan(size.width, size.height * 1.8)
    }

    func testCalendarRespectsFirstWeekdayAndLeapDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2028, month: 2, day: 15)))
        let design = WidgetDesign(name: "달력", template: .calendar, title: "")
        let cells = design.monthCells(at: date, calendar: calendar)
        XCTAssertEqual(cells.count % 7, 0)
        XCTAssertNil(cells[0]) // 2028년 2월 1일은 화요일.
        XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(cells[1])), 1)
        XCTAssertEqual(cells.compactMap { $0 }.count, 29)
    }
}

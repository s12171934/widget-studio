import XCTest
@testable import WidgetStudio

final class PomodoroTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000.123456)

    func testDefaultCycleTransitionsThroughBreaksAndRestarts() {
        let session = PomodoroSession(settings: PomodoroSettings(), startedAt: start)
        let focus = session.snapshot(at: start)
        XCTAssertEqual(focus.phase, .focus)
        XCTAssertEqual(focus.remaining, 1500)
        XCTAssertEqual(focus.completedFocus, 0)
        let rest = session.snapshot(at: start.addingTimeInterval(1500))
        XCTAssertEqual(rest.phase, .shortBreak)
        XCTAssertEqual(rest.remaining, 300)
        XCTAssertEqual(rest.completedFocus, 1)
        let next = session.snapshot(at: start.addingTimeInterval(1800))
        XCTAssertEqual(next.phase, .focus)
        XCTAssertEqual(next.round, 2)
        let longRest = session.snapshot(at: start.addingTimeInterval(6900))
        XCTAssertEqual(longRest.phase, .longBreak)
        XCTAssertEqual(longRest.completedFocus, 4)
        XCTAssertEqual(longRest.remaining, 900)
        let restart = session.snapshot(at: start.addingTimeInterval(7800))
        XCTAssertEqual(restart.phase, .focus)
        XCTAssertEqual(restart.round, 1)
        XCTAssertEqual(restart.completedFocus, 4)
    }

    func testPauseDuringBreakAndResumeDoNotAdvanceWhilePaused() {
        var session = PomodoroSession(settings: PomodoroSettings(), startedAt: start)
        session.toggle(at: start.addingTimeInterval(1560))
        let paused = session.snapshot(at: start.addingTimeInterval(100_000))
        XCTAssertFalse(paused.isRunning)
        XCTAssertEqual(paused.phase, .shortBreak)
        XCTAssertEqual(paused.remaining, 240)
        XCTAssertEqual(paused.completedFocus, 1)
        session.toggle(at: start.addingTimeInterval(100_000))
        let resumed = session.snapshot(at: start.addingTimeInterval(100_060))
        XCTAssertTrue(resumed.isRunning)
        XCTAssertEqual(resumed.remaining, 180)
        XCTAssertEqual(resumed.phase, .shortBreak)
    }

    func testLongBackgroundAbsenceComputesCurrentPhaseWithoutRunningApp() {
        let session = PomodoroSession(settings: PomodoroSettings(), startedAt: start)
        let snapshot = session.snapshot(at: start.addingTimeInterval(7800 * 1000 + 1500))
        XCTAssertEqual(snapshot.phase, .shortBreak)
        XCTAssertEqual(snapshot.completedFocus, 4001)
        XCTAssertEqual(snapshot.remaining, 300)
    }

    func testOneRoundSettingGoesDirectlyToLongBreak() {
        let settings = PomodoroSettings(focusMinutes: 1, shortBreakMinutes: 2, longBreakMinutes: 3, rounds: 1)
        let session = PomodoroSession(settings: settings, startedAt: start)
        let snapshot = session.snapshot(at: start.addingTimeInterval(60))
        XCTAssertEqual(snapshot.phase, .longBreak)
        XCTAssertEqual(snapshot.remaining, 180)
        XCTAssertEqual(session.snapshot(at: start.addingTimeInterval(240)).completedFocus, 1)
    }

    func testTimelineDatesAreStrictlyIncreasingAtFractionalDateBoundaries() {
        let session = PomodoroSession(settings: PomodoroSettings(), startedAt: start)
        let dates = session.transitionDates(after: start.addingTimeInterval(12.345))
        XCTAssertEqual(dates.count, 16)
        XCTAssertEqual(session.snapshot(at: dates[0]).phase, .shortBreak)
        XCTAssertEqual(session.snapshot(at: dates[7]).phase, .focus)
        for (first, next) in zip(dates, dates.dropFirst()) { XCTAssertGreaterThan(next, first) }
    }

    func testSettingsChangesDoNotChangeRunningSessionUntilReset() throws {
        var design = WidgetDesign(name: "포모도로", template: .pomodoro, title: "")
        var state = WidgetActivity()
        state.apply(.toggleTimer, to: design, at: start)
        design.pomodoroSettings.focusMinutes = 10
        XCTAssertEqual(state.pomodoroSnapshot(for: design, at: start).remaining, 1500)
        let saved = try JSONDecoder().decode(WidgetActivity.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(saved.pomodoroSnapshot(for: design, at: start.addingTimeInterval(1500)).phase, .shortBreak)
        state.apply(.resetTimer, to: design)
        XCTAssertNil(state.pomodoro)
        XCTAssertEqual(state.pomodoroSnapshot(for: design, at: start).remaining, 600)
        state.apply(.toggleTimer, to: design, at: start)
        XCTAssertEqual(state.pomodoroSnapshot(for: design, at: start).remaining, 600)
    }

    func testPreviousActivityAndDesignDecodeWithoutPomodoroKeys() throws {
        let activity = try JSONDecoder().decode(WidgetActivity.self, from: Data("{\"completedItems\":[]}".utf8))
        XCTAssertNil(activity.pomodoro)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(WidgetDesign.samples[0])) as? [String: Any])
        json.removeValue(forKey: "pomodoroSettings")
        let design = try JSONDecoder().decode(WidgetDesign.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(design.pomodoroSettings, PomodoroSettings())
    }

    func testInvalidDurationsClampToUsableCycle() {
        let settings = PomodoroSettings(focusMinutes: 0, shortBreakMinutes: -1, longBreakMinutes: 1000, rounds: 0)
        XCTAssertEqual(settings.validated, PomodoroSettings(focusMinutes: 1, shortBreakMinutes: 1, longBreakMinutes: 120, rounds: 1))
        let session = PomodoroSession(settings: settings, startedAt: start)
        XCTAssertEqual(session.snapshot(at: start).remaining, 60)
        XCTAssertEqual(session.transitionDates(after: start).count, 4)
    }

    func testBothAppearancesPersistAndOldDesignsKeepDigitalStyle() throws {
        for appearance in WidgetDesign.PomodoroAppearance.allCases {
            let design = WidgetDesign(name: "타이머", template: .pomodoro, title: "", pomodoroAppearance: appearance)
            let decoded = try JSONDecoder().decode(WidgetDesign.self, from: JSONEncoder().encode(design))
            XCTAssertEqual(decoded.pomodoroAppearance, appearance)
        }
        let original = WidgetDesign(name: "기존 타이머", template: .pomodoro, title: "")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "pomodoroAppearance")
        let decoded = try JSONDecoder().decode(WidgetDesign.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.pomodoroAppearance, .digital)
    }
}

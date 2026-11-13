import Foundation

struct ChecklistItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
}

enum WidgetAction: String, Codable {
    case toggleItem, increment, decrement, resetCounter, toggleTimer, resetTimer
    case decreaseTimerMinutes, increaseTimerMinutes
}

/// 위젯에서 바뀐 값은 디자인 설정과 따로 보관해, 편집기 저장이 진행 상황을 덮지 않는다.
struct WidgetActivity: Codable, Hashable {
    var completedItems: Set<UUID> = []
    var counterValue: Int?
    var timerEnd: Date?
    var pausedSeconds: TimeInterval?
    var pomodoro: PomodoroSession?
    var pomodoroFocusMinutes: Int?

    func pomodoroSettings(for design: WidgetDesign) -> PomodoroSettings {
        var settings = design.pomodoroSettings.validated
        if let pomodoroFocusMinutes { settings.focusMinutes = pomodoroFocusMinutes }
        return settings
    }

    func remainingSeconds(for design: WidgetDesign, at date: Date) -> TimeInterval {
        if let timerEnd { return max(0, timerEnd.timeIntervalSince(date)) }
        return pausedSeconds ?? TimeInterval(min(max(design.focusMinutes, 1), 180) * 60)
    }

    func timerIsRunning(at date: Date) -> Bool { (timerEnd ?? .distantPast) > date }

    mutating func apply(_ action: WidgetAction, to design: WidgetDesign, itemID: UUID? = nil,
                        at date: Date = .now) {
        switch (design.template, action) {
        case (.checklist, .toggleItem):
            guard let itemID, design.checklistItems.contains(where: { $0.id == itemID }) else { return }
            if completedItems.contains(itemID) { completedItems.remove(itemID) }
            else { completedItems.insert(itemID) }
        case (.counter, .increment), (.counter, .decrement):
            let step = min(max(design.counterStep, 1), 1000) * (action == .increment ? 1 : -1)
            let result = (counterValue ?? design.counterStart).addingReportingOverflow(step)
            if !result.overflow { counterValue = result.partialValue }
        case (.counter, .resetCounter): counterValue = nil
        case (.focus, .toggleTimer):
            let remaining = remainingSeconds(for: design, at: date)
            if timerIsRunning(at: date) {
                pausedSeconds = remaining
                timerEnd = nil
            } else {
                let duration = remaining > 0 ? remaining : TimeInterval(min(max(design.focusMinutes, 1), 180) * 60)
                timerEnd = date.addingTimeInterval(duration)
                pausedSeconds = nil
            }
        case (.focus, .resetTimer):
            timerEnd = nil
            pausedSeconds = nil
        case (.pomodoro, .toggleTimer):
            var session = pomodoro ?? PomodoroSession(settings: pomodoroSettings(for: design))
            session.toggle(at: date)
            pomodoro = session
        case (.pomodoro, .resetTimer): pomodoro = nil
        case (.pomodoro, .decreaseTimerMinutes), (.pomodoro, .increaseTimerMinutes):
            guard pomodoro?.startedAt == nil else { return }
            let current = pomodoroSettings(for: design).focusMinutes
            let next = min(max(current + (action == .increaseTimerMinutes ? 5 : -5), 5), 60)
            guard next != current else { return }
            pomodoroFocusMinutes = next
            pomodoro = nil
        default: break
        }
    }
}

extension WidgetDesign {
    /// 현재 월의 첫 요일 앞에 빈칸을 두고, 달력 행을 7칸으로 채운다.
    func monthCells(at date: Date, calendar: Calendar = .current) -> [Date?] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let offset = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        var cells = Array<Date?>(repeating: nil, count: offset)
        cells += days.map { calendar.date(byAdding: .day, value: $0 - 1, to: month.start) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

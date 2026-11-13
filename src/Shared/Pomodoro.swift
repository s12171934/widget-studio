import Foundation

struct PomodoroSettings: Codable, Hashable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var rounds = 4

    var validated: Self {
        Self(focusMinutes: min(max(focusMinutes, 1), 180),
             shortBreakMinutes: min(max(shortBreakMinutes, 1), 60),
             longBreakMinutes: min(max(longBreakMinutes, 1), 120),
             rounds: min(max(rounds, 1), 12))
    }

    var cycleSeconds: TimeInterval {
        let s = validated
        return TimeInterval((s.focusMinutes * s.rounds + s.shortBreakMinutes * (s.rounds - 1) + s.longBreakMinutes) * 60)
    }
}

struct PomodoroSnapshot: Hashable {
    enum Phase: String {
        case focus, shortBreak, longBreak
        var label: String {
            switch self {
            case .focus: return "집중"
            case .shortBreak: return "짧은 휴식"
            case .longBreak: return "긴 휴식"
            }
        }
        var symbol: String { self == .focus ? "brain.head.profile" : "cup.and.saucer.fill" }
    }

    let phase: Phase
    let round: Int
    let completedFocus: Int
    let duration: TimeInterval
    let remaining: TimeInterval
    let isRunning: Bool
    let endDate: Date?
    let settings: PomodoroSettings

    var showsDialCountdown: Bool { remaining <= 300 }
}

/// 시작 시 설정을 유지하고 경과 시간으로 단계를 계산한다. 백그라운드 실행은 필요 없다.
struct PomodoroSession: Codable, Hashable {
    var settings: PomodoroSettings
    var startedAt: Date?
    var elapsedBeforeStart: TimeInterval = 0

    func elapsed(at date: Date) -> TimeInterval {
        let seconds = elapsedBeforeStart + (startedAt.map { date.timeIntervalSince($0) } ?? 0)
        guard seconds.isFinite else { return 0 }
        let bounded = min(max(0, seconds), settings.cycleSeconds * 1_000_000_000)
        // Date의 소수점 오차 때문에 단계 경계가 0초 직전에 머무는 것을 막는다.
        return (bounded * 1000).rounded() / 1000
    }

    func snapshot(at date: Date) -> PomodoroSnapshot {
        let s = settings.validated
        let elapsed = elapsed(at: date)
        let cycles = Int(floor(elapsed / s.cycleSeconds))
        var offset = elapsed.truncatingRemainder(dividingBy: s.cycleSeconds)
        var completed = cycles * s.rounds
        for round in 1...s.rounds {
            let focus = TimeInterval(s.focusMinutes * 60)
            if offset < focus {
                return makeSnapshot(.focus, round: round, completed: completed, duration: focus,
                                    remaining: focus - offset, at: date)
            }
            offset -= focus
            completed += 1
            let phase: PomodoroSnapshot.Phase = round == s.rounds ? .longBreak : .shortBreak
            let rest = TimeInterval((phase == .longBreak ? s.longBreakMinutes : s.shortBreakMinutes) * 60)
            if offset < rest {
                return makeSnapshot(phase, round: round, completed: completed, duration: rest,
                                    remaining: rest - offset, at: date)
            }
            offset -= rest
        }
        // 부동소수점 경계에서만 도달하며 다음 집중 단계로 이어진다.
        return makeSnapshot(.focus, round: 1, completed: completed, duration: TimeInterval(s.focusMinutes * 60),
                            remaining: TimeInterval(s.focusMinutes * 60), at: date)
    }

    private func makeSnapshot(_ phase: PomodoroSnapshot.Phase, round: Int, completed: Int,
                              duration: TimeInterval, remaining: TimeInterval, at date: Date) -> PomodoroSnapshot {
        PomodoroSnapshot(phase: phase, round: round, completedFocus: completed, duration: duration,
                         remaining: remaining, isRunning: startedAt != nil,
                         endDate: startedAt == nil ? nil : date.addingTimeInterval(remaining), settings: settings.validated)
    }

    mutating func toggle(at date: Date) {
        if startedAt != nil {
            elapsedBeforeStart = elapsed(at: date)
            startedAt = nil
        } else { startedAt = date }
    }

    /// 다음 두 묶음의 단계 경계를 미리 예약하고 마지막 항목에서 타임라인을 다시 요청한다.
    func transitionDates(after date: Date, includingCountdownStart: Bool = false) -> [Date] {
        guard startedAt != nil else { return [] }
        var dates: [Date] = []
        var cursor = date
        for _ in 0..<(settings.validated.rounds * 4) {
            guard let end = snapshot(at: cursor).endDate, end > cursor else { break }
            let countdownStart = end.addingTimeInterval(-300)
            if includingCountdownStart, countdownStart > cursor {
                dates.append(countdownStart)
            }
            dates.append(end)
            cursor = end
        }
        return dates
    }
}

extension WidgetActivity {
    func pomodoroSnapshot(for design: WidgetDesign, at date: Date) -> PomodoroSnapshot {
        (pomodoro ?? PomodoroSession(settings: pomodoroSettings(for: design))).snapshot(at: date)
    }
}

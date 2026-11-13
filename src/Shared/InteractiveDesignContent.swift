import SwiftUI
import WidgetKit

struct InteractiveDesignContent: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let date: Date
    let activity: WidgetActivity
    var widgetControls = false
    var layoutSize: CGSize?
    var onAction: ((WidgetAction, UUID?) -> Void)?

    private var compact: Bool { family == .systemSmall || family == .systemMedium }
    private var extraLarge: Bool { family == .systemExtraLarge }

    var body: some View {
        Group {
            switch design.template {
            case .checklist: checklist
            case .counter: counter
            case .focus: focus
            case .pomodoro:
                if design.pomodoroAppearance == .dial { pomodoroDial }
                else { pomodoro }
            case .calendar: monthCalendar
            default: EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func heading(_ fallback: String) -> some View {
        Text(design.title.isEmpty ? fallback : design.title)
            .font(design.font(size: compact ? 13 : 20, weight: .bold))
            .lineLimit(1)
            .widgetAccentable()
    }

    private var checklist: some View {
        let limit = extraLarge ? 14 : (compact ? 2 : 7)
        let items = Array(design.checklistItems.prefix(limit))
        let complete = design.checklistItems.filter { activity.completedItems.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: compact ? 5 : 10) {
            HStack {
                heading("체크리스트")
                Spacer(minLength: 4)
                Text("\(complete)/\(design.checklistItems.count)")
                    .font(.caption.monospacedDigit())
                    .invalidatableContent()
            }
            if items.isEmpty {
                Text("앱에서 할 일을 추가하세요").font(.caption).opacity(0.75)
            } else if extraLarge {
                HStack(alignment: .top, spacing: 20) {
                    checklistColumn(Array(items.prefix(7)))
                    checklistColumn(Array(items.dropFirst(7)))
                }
            } else {
                checklistColumn(items)
            }
            if design.checklistItems.count > limit {
                Text("외 \(design.checklistItems.count - limit)개 · 앱에서 전체 보기")
                    .font(.system(size: 10)).opacity(0.7).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func checklistColumn(_ items: [ChecklistItem]) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            ForEach(items) { item in
                let complete = activity.completedItems.contains(item.id)
                actionButton(item.title, symbol: complete ? "checkmark.circle.fill" : "circle",
                             action: .toggleItem, itemID: item.id, complete: complete)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var counter: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 16) {
            heading("카운터")
            if family == .systemMedium || extraLarge {
                HStack(spacing: 18) {
                    counterNumber
                    Spacer(minLength: 0)
                    counterButtons
                }
            } else {
                counterNumber
                counterButtons
            }
            if !compact {
                ProgressView(value: Double(max(0, activity.counterValue ?? design.counterStart)),
                             total: Double(max(1, design.counterGoal)))
                    .tint(.primary)
                Text("목표 \(design.counterGoal) · 한 번에 \(design.counterStep)")
                    .font(.caption).opacity(0.75)
                if !design.subtitle.isEmpty { Text(design.subtitle).font(.caption).lineLimit(2) }
            }
            Spacer(minLength: 0)
        }
    }

    private var counterNumber: some View {
        Text((activity.counterValue ?? design.counterStart).formatted())
            .font(design.font(size: compact ? 40 : 76, weight: .bold))
            .monospacedDigit()
            .minimumScaleFactor(0.25)
            .lineLimit(1)
            .widgetAccentable()
            .invalidatableContent()
            .accessibilityIdentifier("counter-value")
    }

    private var counterButtons: some View {
        HStack(spacing: 6) {
            actionButton("", symbol: "minus", action: .decrement, accessibility: "카운터 감소")
            actionButton("", symbol: "arrow.counterclockwise", action: .resetCounter, accessibility: "카운터 초기화")
            actionButton("", symbol: "plus", action: .increment, accessibility: "카운터 증가")
        }
    }

    private var focus: some View {
        let running = activity.timerIsRunning(at: date)
        let seconds = activity.remainingSeconds(for: design, at: date)
        return VStack(alignment: .leading, spacing: compact ? 5 : 20) {
            heading("집중 타이머")
            Group {
                if running, let end = activity.timerEnd {
                    Text(timerInterval: date...end, countsDown: true)
                } else if seconds == 0 {
                    Text("완료")
                } else {
                    Text(String(format: "%02d:%02d", Int(ceil(seconds)) / 60, Int(ceil(seconds)) % 60))
                }
            }
            .font(design.font(size: compact ? 32 : 64, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .widgetAccentable()
            .invalidatableContent()
            HStack(spacing: 6) {
                actionButton(running ? "정지" : (seconds == 0 ? "다시" : "시작"),
                             symbol: running ? "pause.fill" : "play.fill", action: .toggleTimer)
                actionButton("", symbol: "arrow.counterclockwise", action: .resetTimer, accessibility: "타이머 초기화")
            }
            if !compact {
                Text("\(design.focusMinutes)분 집중 · \(running ? "진행 중" : (seconds == 0 ? "수고했어요" : "준비되면 시작하세요"))")
                    .font(.callout).opacity(0.75)
                if !design.subtitle.isEmpty { Text(design.subtitle).font(.caption).lineLimit(3) }
            }
            Spacer(minLength: 0)
        }
    }

    private var monthCalendar: some View {
        HStack(alignment: .top, spacing: 24) {
            if extraLarge {
                VStack(alignment: .leading, spacing: 14) {
                    heading("월간 달력")
                    Text(date, format: .dateTime.day())
                        .font(design.font(size: 80, weight: .bold)).widgetAccentable()
                    Text(date, format: .dateTime.weekday(.wide)).font(.title3)
                    if !design.subtitle.isEmpty { Text(design.subtitle).font(.caption).lineLimit(3) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: compact ? 3 : 12) {
                Text(date, format: .dateTime.year().month(.wide))
                    .font(design.font(size: compact ? 13 : 24, weight: .bold))
                    .widgetAccentable()
                calendarGrid
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var pomodoro: some View {
        let snapshot = activity.pomodoroSnapshot(for: design, at: date)
        return VStack(alignment: .leading, spacing: compact ? 3 : 14) {
            heading("포모도로")
            if extraLarge {
                HStack(alignment: .top, spacing: 32) {
                    pomodoroClock(snapshot)
                    pomodoroDetails(snapshot)
                }
            } else {
                pomodoroClock(snapshot)
                if !compact { pomodoroDetails(snapshot) }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var pomodoroDial: some View {
        let snapshot = activity.pomodoroSnapshot(for: design, at: date)
        if widgetControls, let layoutSize {
            dialLayout(snapshot, size: layoutSize)
        } else {
            GeometryReader { geometry in dialLayout(snapshot, size: geometry.size) }
        }
    }

    private func dialLayout(_ snapshot: PomodoroSnapshot, size: CGSize) -> some View {
        Group {
            if family == .systemSmall {
                VStack(spacing: 3) {
                    PomodoroDial(snapshot: snapshot, date: date,
                                 side: max(1, min(size.width, size.height - 31)), systemTimer: widgetControls)
                    pomodoroButtons(snapshot)
                        .frame(height: 28)
                }
            } else if family == .systemMedium || extraLarge {
                HStack(spacing: extraLarge ? 28 : 12) {
                    PomodoroDial(snapshot: snapshot, date: date,
                                 side: min(size.height, size.width * 0.48), systemTimer: widgetControls)
                    VStack(alignment: .leading, spacing: extraLarge ? 18 : 6) {
                        heading("포모도로")
                        Text(snapshot.phase.label).font(extraLarge ? .title2.bold() : .caption.bold())
                        Text("완료 \(snapshot.completedFocus)회").font(.caption).opacity(0.75)
                        pomodoroButtons(snapshot)
                        if extraLarge { pomodoroDetails(snapshot) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    heading("포모도로").frame(height: 24)
                    PomodoroDial(snapshot: snapshot, date: date,
                                 side: max(1, min(size.width, size.height - 98)), systemTimer: widgetControls)
                    pomodoroButtons(snapshot).frame(height: 34)
                    Text("완료 \(snapshot.completedFocus)회 · \(snapshot.settings.rounds)회마다 긴 휴식")
                        .font(.caption).opacity(0.75).frame(height: 16)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func pomodoroButtons(_ snapshot: PomodoroSnapshot) -> some View {
        HStack(spacing: 6) {
            actionButton(snapshot.isRunning ? "정지" : (activity.pomodoro == nil ? "시작" : "재개"),
                         symbol: snapshot.isRunning ? "pause.fill" : "play.fill", action: .toggleTimer)
            actionButton("", symbol: "arrow.counterclockwise", action: .resetTimer, accessibility: "포모도로 초기화")
        }
    }

    private func pomodoroClock(_ snapshot: PomodoroSnapshot) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 12) {
            HStack {
                Label(snapshot.phase.label, systemImage: snapshot.phase.symbol)
                    .widgetAccentable()
                Spacer(minLength: 2)
                Text("\(snapshot.round)/\(snapshot.settings.rounds)")
                    .monospacedDigit()
            }
            .font(design.font(size: compact ? 10 : 16, weight: .semibold))
            .accessibilityIdentifier("pomodoro-phase")
            Group {
                if snapshot.isRunning, let end = snapshot.endDate, end > date {
                    Text(timerInterval: date...end, countsDown: true)
                } else {
                    Text(String(format: "%02d:%02d", Int(ceil(snapshot.remaining)) / 60, Int(ceil(snapshot.remaining)) % 60))
                }
            }
            .font(design.font(size: compact ? 29 : 60, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .widgetAccentable()
            .invalidatableContent()
            .accessibilityIdentifier("pomodoro-remaining")
            HStack(spacing: 6) {
                actionButton(snapshot.isRunning ? "정지" : (activity.pomodoro == nil ? "시작" : "재개"),
                             symbol: snapshot.isRunning ? "pause.fill" : "play.fill", action: .toggleTimer)
                actionButton("", symbol: "arrow.counterclockwise", action: .resetTimer, accessibility: "포모도로 초기화")
            }
            Text("완료 \(snapshot.completedFocus)회")
                .font(design.font(size: compact ? 10 : 15, weight: .medium))
                .opacity(0.75)
                .invalidatableContent()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pomodoroDetails(_ snapshot: PomodoroSnapshot) -> some View {
        let completed = snapshot.phase == .longBreak ? snapshot.settings.rounds : snapshot.completedFocus % snapshot.settings.rounds
        return VStack(alignment: .leading, spacing: 12) {
            if let end = snapshot.endDate {
                ProgressView(timerInterval: end.addingTimeInterval(-snapshot.duration)...end, countsDown: false)
                    .labelsHidden()
                    .tint(.primary)
            } else {
                ProgressView(value: snapshot.duration - snapshot.remaining, total: snapshot.duration)
                    .tint(.primary)
            }
            HStack(spacing: 8) {
                ForEach(1...snapshot.settings.rounds, id: \.self) { round in
                    Image(systemName: round <= completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: snapshot.settings.rounds > 8 ? 14 : 20))
                        .widgetAccentable(round <= completed)
                }
            }
            Text("집중 \(snapshot.settings.focusMinutes)분 · 휴식 \(snapshot.settings.shortBreakMinutes)분")
                .font(.callout)
            Text("\(snapshot.settings.rounds)회마다 \(snapshot.settings.longBreakMinutes)분 긴 휴식")
                .font(.caption).opacity(0.75)
            if !design.subtitle.isEmpty { Text(design.subtitle).font(.caption).lineLimit(2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let cells = design.monthCells(at: date)
        let symbols = calendar.veryShortWeekdaySymbols
        return Grid(horizontalSpacing: 2, verticalSpacing: compact ? 2 : 5) {
            GridRow {
                ForEach(0..<7, id: \.self) { column in
                    Text(symbols[(column + calendar.firstWeekday - 1) % 7])
                        .font(.system(size: compact ? 9 : 13, weight: .medium))
                        .opacity(0.65)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<(cells.count / 7), id: \.self) { row in
                GridRow {
                    ForEach(0..<7, id: \.self) { column in
                        let day = cells[row * 7 + column]
                        let today = day.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                        Text(day.map { String(calendar.component(.day, from: $0)) } ?? " ")
                            .font(design.font(size: compact ? 10 : 17, weight: today ? .heavy : .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: compact ? 12 : 30)
                            .background(.primary.opacity(today ? 0.22 : 0), in: .capsule)
                            .widgetAccentable(today)
                    }
                }
            }
        }
    }

    private func actionButton(_ title: String, symbol: String, action: WidgetAction,
                              itemID: UUID? = nil, complete: Bool = false, accessibility: String? = nil) -> some View {
        Group {
            if widgetControls {
                Button(intent: WidgetActionIntent(designID: design.id, action: action, itemID: itemID)) {
                    controlLabel(title, symbol: symbol, complete: complete)
                }
            } else {
                Button { onAction?(action, itemID) } label: {
                    controlLabel(title, symbol: symbol, complete: complete)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility ?? (complete ? "완료 취소: \(title)" : title))
        .accessibilityIdentifier("widget-\(action.rawValue)\(itemID.map { "-\($0.uuidString)" } ?? "")")
    }

    private func controlLabel(_ title: String, symbol: String, complete: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).widgetAccentable()
            if !title.isEmpty {
                Text(title).strikethrough(complete).lineLimit(1)
                if design.template == .checklist { Spacer(minLength: 0) }
            }
        }
        .font(design.font(size: compact ? 12 : 15, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: compact ? 28 : 34)
        .padding(.horizontal, 5)
        .background(.primary.opacity(complete ? 0.2 : 0.1), in: .rect(cornerRadius: 9))
        .contentShape(.rect)
    }
}

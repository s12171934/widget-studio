import SwiftUI
import WidgetKit

struct PomodoroSector: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        let value = min(max(fraction, 0), 1)
        if value >= 1 { return Path(ellipseIn: rect) }
        guard value > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2,
                    startAngle: .degrees(-90), endAngle: .degrees(-90 + value * 360), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// 아날로그 눈금과 실제 남은 시간. 위젯의 부채꼴은 시스템 타이머 텍스트가 매초 갱신한다.
struct PomodoroDial: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let snapshot: PomodoroSnapshot
    let date: Date
    let side: CGFloat
    var systemTimer = false

    private var glass: Bool { renderingMode != .fullColor }
    private var ink: Color { glass ? .white : Color(red: 0.12, green: 0.14, blue: 0.18) }
    private let spanMinutes = 60

    var body: some View {
            ZStack {
                Circle()
                    .fill(glass ? Color.white.opacity(0.12) : Color(red: 0.99, green: 0.98, blue: 0.96))
                sector(side: side)
                    .frame(width: side, height: side)
                    .widgetAccentable(glass)
                    .accessibilityHidden(true)
                Circle().strokeBorder(ink.opacity(0.15), lineWidth: max(1, side * 0.012))
                ForEach(0..<60, id: \.self) { tick in
                    Rectangle()
                        .fill(ink.opacity(tick % 5 == 0 ? 0.9 : 0.35))
                        .frame(width: max(0.7, side * (tick % 5 == 0 ? 0.008 : 0.004)),
                               height: side * (tick % 5 == 0 ? 0.055 : 0.025))
                        .offset(y: -side * 0.46)
                        .rotationEffect(.degrees(Double(tick) * 6))
                }
                Circle().fill(ink).frame(width: side * 0.035, height: side * 0.035)
                if snapshot.showsDialCountdown {
                    remainingTime
                    .font(.system(size: side * 0.16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                    .frame(width: side * 0.60, height: side * 0.20)
                    .foregroundStyle(ink)
                    .padding(.horizontal, side * 0.025)
                    .padding(.vertical, side * 0.012)
                    .background(glass ? Color.black.opacity(0.25) : Color.white.opacity(0.92), in: .capsule)
                    .offset(y: side * 0.15)
                    .accessibilityIdentifier("pomodoro-remaining")
                }
                Text("\(snapshot.phase.label) · \(snapshot.round)/\(snapshot.settings.rounds)")
                    .font(.system(size: side * 0.055, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.75))
                    .offset(y: side * 0.28)
            }
            .frame(width: side, height: side)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pomodoro-dial")
    }

    @ViewBuilder private var remainingTime: some View {
        if snapshot.isRunning, let end = snapshot.endDate, end > date {
            Text(timerInterval: date...end, countsDown: true)
        } else {
            Text(String(format: "%02d:%02d", Int(ceil(snapshot.remaining)) / 60, Int(ceil(snapshot.remaining)) % 60))
        }
    }

    @ViewBuilder private func sector(side: CGFloat) -> some View {
        if systemTimer, snapshot.isRunning, let end = snapshot.endDate, end > date {
            ZStack {
                ForEach(0...4, id: \.self) { place in
                    timedFill(place: place, end: end, side: side)
                }
            }
        } else {
            PomodoroSector(fraction: snapshot.remaining / Double(spanMinutes * 60))
                .fill(Color(red: 0.92, green: 0.12, blue: 0.17))
        }
    }

    /// 상위 자리의 구간으로 하위 자리의 반복 무늬를 잘라 전체 부채꼴을 합친다.
    private func timedFill(place: Int, end: Date, side: CGFloat) -> some View {
        Color(red: 0.92, green: 0.12, blue: 0.17).mask {
            timerDigit(place: place, selector: false, end: end, side: side)
                .mask(prefixMask(place: place, higher: 1, end: end, side: side))
                .mask(prefixMask(place: place, higher: 2, end: end, side: side))
                .mask(prefixMask(place: place, higher: 3, end: end, side: side))
                .mask(prefixMask(place: place, higher: 4, end: end, side: side))
        }
    }

    @ViewBuilder private func prefixMask(place: Int, higher: Int, end: Date, side: CGFloat) -> some View {
        if place < higher {
            ZStack {
                // 타이머가 생략하는 상위 자리는 0으로 취급한다.
                Text("0")
                    .font(.custom(fontName(place: higher, selector: true), fixedSize: side))
                    .foregroundStyle(.white)
                    .frame(width: side, height: side)
                timerDigit(place: higher, selector: true, end: end, side: side)
            }
        } else {
            Color.white
        }
    }

    private func fontName(place: Int, selector: Bool) -> String {
        "WSPomodoro\(spanMinutes)\(selector ? "Select" : "Fill")\(place)-Regular"
    }

    private func timerDigit(place: Int, selector: Bool, end: Date, side: CGFloat) -> some View {
        let positions = [0, 1, 3, 4, 6] // 오른쪽부터 초·십 초·분·십 분·시. 콜론 자리는 건너뛴다.
        return GeometryReader { _ in
            Text(timerInterval: date...end, countsDown: true)
                .font(.custom(fontName(place: place, selector: selector), fixedSize: side))
                .foregroundStyle(.white)
                .frame(width: side * 9, height: side)
                .multilineTextAlignment(.trailing)
                .offset(x: -side * CGFloat(8 - positions[place]))
        }
        .frame(width: side, height: side)
        .clipped()
        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
    }
}

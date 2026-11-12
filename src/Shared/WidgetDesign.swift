import Foundation

/// 위젯 디자인 한 개. 앱이 만들고, 위젯 확장이 읽는다.
struct WidgetDesign: Codable, Identifiable, Hashable {
    enum Template: String, Codable, CaseIterable, Identifiable {
        case text, clock, countdown, photo
        var id: String { rawValue }
        var label: String {
            switch self {
            case .text: return "문구"
            case .clock: return "시계"
            case .countdown: return "D-day"
            case .photo: return "사진"
            }
        }
        var symbol: String {
            switch self {
            case .text: return "text.quote"
            case .clock: return "clock"
            case .countdown: return "calendar.badge.clock"
            case .photo: return "photo"
            }
        }
    }

    enum FontStyle: String, Codable, CaseIterable, Identifiable {
        case standard, rounded, serif, mono
        var id: String { rawValue }
        var label: String {
            switch self {
            case .standard: return "기본"
            case .rounded: return "둥근"
            case .serif: return "명조"
            case .mono: return "고정폭"
            }
        }
    }

    enum Alignment: String, Codable, CaseIterable, Identifiable {
        case leading, center
        var id: String { rawValue }
        var label: String { self == .leading ? "왼쪽" : "가운데" }
    }

    var id: UUID = UUID()
    var name: String
    var template: Template
    var title: String
    var subtitle: String = ""
    var targetDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    var backgroundHex: String = "#1E3A8A"
    var gradientHex: String = "#7C3AED"
    var useGradient: Bool = true
    var textHex: String = "#FFFFFF"
    var fontStyle: FontStyle = .rounded
    var alignment: Alignment = .leading
    var photoDimming: Double = 0.25
    var updatedAt: Date = .now

    /// 기준일(date)에서 목표일까지 남은 날짜 수. 지난 날짜면 음수.
    func daysRemaining(from date: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.startOfDay(for: targetDate)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func dDayLabel(from date: Date) -> String {
        let d = daysRemaining(from: date)
        if d == 0 { return "D-DAY" }
        return d > 0 ? "D-\(d)" : "D+\(-d)"
    }
}

extension WidgetDesign {
    static let samples: [WidgetDesign] = [
        WidgetDesign(name: "저녁 하늘 시계", template: .clock, title: "오늘도 좋은 하루",
                     backgroundHex: "#0F172A", gradientHex: "#7C3AED", fontStyle: .rounded),
        WidgetDesign(name: "여행 D-day", template: .countdown, title: "제주 여행",
                     targetDate: Calendar.current.date(byAdding: .day, value: 24, to: .now) ?? .now,
                     backgroundHex: "#F97316", gradientHex: "#DB2777", fontStyle: .rounded),
        WidgetDesign(name: "오늘의 문구", template: .text, title: "천천히, 그러나 멈추지 않고",
                     subtitle: "— 나에게", backgroundHex: "#FEF3C7", gradientHex: "#FDE68A",
                     textHex: "#78350F", fontStyle: .serif, alignment: .center),
    ]
}

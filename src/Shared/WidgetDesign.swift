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
    enum CodingKeys: String, CodingKey {
        case id, name, template, title, subtitle, targetDate, backgroundHex, gradientHex, useGradient,
             textHex, fontStyle, alignment, photoDimming, updatedAt
    }

    /// 필드가 늘거나 줄어도 예전에 저장한 디자인을 읽을 수 있도록, 없는 키는 기본값으로 채우고 모르는 키는 버린다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = WidgetDesign(name: "", template: .text, title: "")
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        template = try c.decodeIfPresent(Template.self, forKey: .template) ?? .text
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? base.subtitle
        targetDate = try c.decodeIfPresent(Date.self, forKey: .targetDate) ?? base.targetDate
        backgroundHex = try c.decodeIfPresent(String.self, forKey: .backgroundHex) ?? base.backgroundHex
        gradientHex = try c.decodeIfPresent(String.self, forKey: .gradientHex) ?? base.gradientHex
        useGradient = try c.decodeIfPresent(Bool.self, forKey: .useGradient) ?? base.useGradient
        textHex = try c.decodeIfPresent(String.self, forKey: .textHex) ?? base.textHex
        fontStyle = try c.decodeIfPresent(FontStyle.self, forKey: .fontStyle) ?? base.fontStyle
        alignment = try c.decodeIfPresent(Alignment.self, forKey: .alignment) ?? base.alignment
        photoDimming = try c.decodeIfPresent(Double.self, forKey: .photoDimming) ?? base.photoDimming
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
    }

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


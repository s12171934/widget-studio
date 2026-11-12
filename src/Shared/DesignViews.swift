import SwiftUI
import UIKit
import WidgetKit

// MARK: - 색

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}

extension WidgetDesign {
    func font(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let design: Font.Design
        switch fontStyle {
        case .standard: design = .default
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .mono: design = .monospaced
        }
        return .system(size: size, weight: weight, design: design)
    }

    var horizontalAlignment: HorizontalAlignment { alignment == .center ? .center : .leading }
    var textAlignment: TextAlignment { alignment == .center ? .center : .leading }
    var frameAlignment: SwiftUI.Alignment { alignment == .center ? .center : .bottomLeading }
}

// MARK: - 배경

/// 위젯에서는 containerBackground 로, 앱 미리보기에서는 카드 배경으로 쓴다.
struct DesignBackground: View {
    let design: WidgetDesign
    var photo: UIImage?

    var body: some View {
        ZStack {
            if design.template == .photo, let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                Color.black.opacity(design.photoDimming)
            } else if design.useGradient {
                LinearGradient(colors: [Color(hex: design.backgroundHex), Color(hex: design.gradientHex)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                Color(hex: design.backgroundHex)
            }
        }
    }
}

// MARK: - 내용

struct DesignContent: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let date: Date

    private var isSmall: Bool { family == .systemSmall }
    private var scale: CGFloat {
        switch family {
        case .systemLarge, .systemExtraLarge: return 1.5
        default: return 1
        }
    }
    private var textColor: Color { Color(hex: design.textHex) }

    var body: some View {
        Group {
            switch design.template {
            case .text: textBody
            case .clock: clockBody
            case .countdown: countdownBody
            case .photo: photoBody
            }
        }
        .foregroundStyle(textColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: design.frameAlignment)
    }

    private var textBody: some View {
        VStack(alignment: design.horizontalAlignment, spacing: 6 * scale) {
            Text(design.title)
                .font(design.font(size: (isSmall ? 20 : 24) * scale, weight: .bold))
                .minimumScaleFactor(0.5)
            if !design.subtitle.isEmpty {
                Text(design.subtitle)
                    .font(design.font(size: 13 * scale, weight: .medium))
                    .opacity(0.8)
            }
        }
        .multilineTextAlignment(design.textAlignment)
    }

    private var clockBody: some View {
        VStack(alignment: design.horizontalAlignment, spacing: 2 * scale) {
            Text(date, format: .dateTime.weekday(.wide).month().day())
                .font(design.font(size: 13 * scale, weight: .medium))
                .opacity(0.85)
            Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                .font(design.font(size: (isSmall ? 44 : 54) * scale, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if !design.title.isEmpty {
                Text(design.title)
                    .font(design.font(size: 12 * scale, weight: .medium))
                    .opacity(0.8)
                    .lineLimit(2)
            }
        }
        .multilineTextAlignment(design.textAlignment)
    }

    private var countdownBody: some View {
        VStack(alignment: design.horizontalAlignment, spacing: 4 * scale) {
            Text(design.title)
                .font(design.font(size: 14 * scale, weight: .semibold))
                .opacity(0.9)
                .lineLimit(2)
            Text(design.dDayLabel(from: date))
                .font(design.font(size: (isSmall ? 40 : 50) * scale, weight: .heavy))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(design.targetDate, format: .dateTime.year().month().day())
                .font(design.font(size: 12 * scale, weight: .medium))
                .opacity(0.75)
        }
        .multilineTextAlignment(design.textAlignment)
    }

    private var photoBody: some View {
        VStack(alignment: design.horizontalAlignment, spacing: 2 * scale) {
            if !design.title.isEmpty {
                Text(design.title)
                    .font(design.font(size: 16 * scale, weight: .bold))
                    .lineLimit(2)
                    .shadow(radius: 3)
            }
            if !design.subtitle.isEmpty {
                Text(design.subtitle)
                    .font(design.font(size: 12 * scale, weight: .medium))
                    .shadow(radius: 3)
            }
        }
        .multilineTextAlignment(design.textAlignment)
    }
}

// MARK: - 앱 안 미리보기 카드

/// 홈 화면 위젯과 같은 크기 비율로 디자인을 그려 보여 준다.
struct DesignPreviewCard: View {
    let design: WidgetDesign
    var family: WidgetFamily = .systemSmall
    var photo: UIImage?
    var date: Date?

    static func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemMedium: return CGSize(width: 338, height: 158)
        case .systemLarge: return CGSize(width: 338, height: 354)
        default: return CGSize(width: 158, height: 158)
        }
    }

    var body: some View {
        let size = Self.size(for: family)
        // 날짜를 고정하지 않으면 분마다 다시 그려 시계·D-day 가 실제처럼 바뀐다.
        TimelineView(.everyMinute) { context in
            DesignContent(design: design, family: family, date: date ?? context.date)
        }
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(DesignBackground(design: design, photo: photo))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

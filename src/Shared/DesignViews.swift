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

    /// 밝은 색 위에서는 검정 글자가 읽히는지 판단할 때 쓴다.
    var isLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.7
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

// MARK: - 홈 화면 표시 방식

/// iOS 26 홈 화면의 아이콘·위젯 스타일. 틴트·클리어에서는 위젯 배경이 Liquid Glass 로 바뀌고
/// 글자는 강조(accent) 그룹과 나머지로 나뉘어 단색으로 그려진다.
enum HomeAppearance: String, CaseIterable, Identifiable {
    case standard, tinted, clear
    var id: String { rawValue }
    var label: String {
        switch self {
        case .standard: return "기본"
        case .tinted: return "틴트"
        case .clear: return "클리어"
        }
    }
    var isGlass: Bool { self != .standard }
}

// MARK: - 배경

/// 기본(전체 색) 모드의 위젯 배경. 위젯에서는 containerBackground 로 쓰여,
/// 틴트·클리어 모드에서는 시스템이 걷어 내고 유리로 바꾼다.
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

/// 유리 모드에서 사진 템플릿은 배경이 걷히므로, 사진을 내용 층으로 올려
/// 시스템이 유리 위에 단색(채도 뺀 강조색)으로 그리게 한다.
struct GlassPhotoLayer: View {
    let photo: UIImage
    /// 앱 미리보기는 시스템 렌더링이 없으므로 흑백·투명도로 흉내 낸다.
    var simulate = false

    var body: some View {
        if simulate {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .grayscale(1)
                .opacity(0.55)
                .blendMode(.plusLighter)
        } else {
            Image(uiImage: photo)
                .resizable()
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .scaledToFill()
        }
    }
}

// MARK: - 내용

struct DesignContent: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let date: Date
    /// 틴트·클리어(유리) 모드. 사용자 글자 색 대신 단색으로 그리고, 강조 그룹만 또렷하게 둔다.
    var glass = false
    /// 유리 모드의 글자 색(앱 미리보기에서 틴트 색을 흉내 낼 때만 바꾼다).
    var glassColor: Color = .white

    private var isSmall: Bool { family == .systemSmall }
    private var scale: CGFloat {
        switch family {
        case .systemLarge, .systemExtraLarge: return 1.5
        default: return 1
        }
    }
    private var textColor: Color { glass ? glassColor : Color(hex: design.textHex) }
    /// 유리 모드에서 강조가 아닌 글자는 한 단계 흐리게.
    private var secondaryOpacity: Double { glass ? 0.62 : 0.8 }

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
                .widgetAccentable()
            if !design.subtitle.isEmpty {
                Text(design.subtitle)
                    .font(design.font(size: 13 * scale, weight: .medium))
                    .opacity(secondaryOpacity)
            }
        }
        .multilineTextAlignment(design.textAlignment)
    }

    private var clockBody: some View {
        VStack(alignment: design.horizontalAlignment, spacing: 2 * scale) {
            Text(date, format: .dateTime.weekday(.wide).month().day())
                .font(design.font(size: 13 * scale, weight: .medium))
                .opacity(secondaryOpacity)
            Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits))
                .font(design.font(size: (isSmall ? 44 : 54) * scale, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .widgetAccentable()
            if !design.title.isEmpty {
                Text(design.title)
                    .font(design.font(size: 12 * scale, weight: .medium))
                    .opacity(secondaryOpacity)
                    .lineLimit(2)
            }
        }
        .multilineTextAlignment(design.textAlignment)
    }

    private var countdownBody: some View {
        VStack(alignment: design.horizontalAlignment, spacing: 4 * scale) {
            Text(design.title)
                .font(design.font(size: 14 * scale, weight: .semibold))
                .opacity(glass ? secondaryOpacity : 0.9)
                .lineLimit(2)
            Text(design.dDayLabel(from: date))
                .font(design.font(size: (isSmall ? 40 : 50) * scale, weight: .heavy))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .widgetAccentable()
            Text(design.targetDate, format: .dateTime.year().month().day())
                .font(design.font(size: 12 * scale, weight: .medium))
                .opacity(glass ? secondaryOpacity : 0.75)
        }
        .multilineTextAlignment(design.textAlignment)
    }

    private var photoBody: some View {
        VStack(alignment: design.horizontalAlignment, spacing: 2 * scale) {
            if !design.title.isEmpty {
                Text(design.title)
                    .font(design.font(size: 16 * scale, weight: .bold))
                    .lineLimit(2)
                    .shadow(radius: glass ? 0 : 3)
                    .widgetAccentable()
            }
            if !design.subtitle.isEmpty {
                Text(design.subtitle)
                    .font(design.font(size: 12 * scale, weight: .medium))
                    .shadow(radius: glass ? 0 : 3)
            }
        }
        .multilineTextAlignment(design.textAlignment)
    }
}

// MARK: - 앱 안 미리보기 카드

/// 홈 화면 위젯과 같은 크기 비율로 디자인을 그려 보여 준다.
/// 유리 모드는 실제 Liquid Glass 로 그려 뒤의 배경화면을 굴절시킨다.
struct DesignPreviewCard: View {
    let design: WidgetDesign
    var family: WidgetFamily = .systemSmall
    var photo: UIImage?
    var date: Date?
    var appearance: HomeAppearance = .standard
    /// 틴트 모드에서 홈 화면이 입히는 색.
    var tint: Color = .blue

    static let cornerRadius: CGFloat = 24

    static func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemMedium: return CGSize(width: 338, height: 158)
        case .systemLarge: return CGSize(width: 338, height: 354)
        default: return CGSize(width: 158, height: 158)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    }

    var body: some View {
        let size = Self.size(for: family)
        // 날짜를 고정하지 않으면 분마다 다시 그려 시계·D-day 가 실제처럼 바뀐다.
        let content = TimelineView(.everyMinute) { context in
            DesignContent(design: design, family: family, date: date ?? context.date,
                          glass: appearance.isGlass,
                          glassColor: appearance == .tinted ? tint.mix(with: .white, by: 0.55) : .white)
                .padding(16)
        }
        .frame(width: size.width, height: size.height)

        switch appearance {
        case .standard:
            content
                .background(DesignBackground(design: design, photo: photo))
                .clipShape(shape)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        case .tinted, .clear:
            content
                .background {
                    if design.template == .photo, let photo {
                        GlassPhotoLayer(photo: photo, simulate: true)
                            .clipShape(shape)
                    }
                }
                .glassEffect(appearance == .tinted ? .regular.tint(tint.opacity(0.35)) : .clear,
                             in: shape)
        }
    }
}

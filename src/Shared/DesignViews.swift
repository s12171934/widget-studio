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
    func imageLayout(for family: WidgetFamily) -> WidgetImageLayout {
        imageLayouts[family.studioSizeKey] ?? WidgetImageLayout()
    }

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

extension WidgetFamily {
    var studioSizeKey: String {
        switch self {
        case .systemMedium: return "medium"
        case .systemLarge: return "large"
        case .systemExtraLarge: return "extraLarge"
        default: return "small"
        }
    }

    var studioSizeLabel: String {
        switch self {
        case .systemMedium: return "중간"
        case .systemLarge: return "크게"
        case .systemExtraLarge: return "X-large"
        default: return "작게"
        }
    }
}

/// 미리보기·사진·GIF의 모든 프레임에 같은 맞춤·확대·위치 계산을 사용한다.
struct WidgetImageView: View {
    let image: UIImage
    let layout: WidgetImageLayout
    var glass = false

    var body: some View {
        GeometryReader { geometry in
            let rect = layout.imageRect(image: image.size, viewport: geometry.size)
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(glass ? .accentedDesaturated : .fullColor)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
        .clipped()
    }
}

// MARK: - 배경

/// 위젯 배경. containerBackground 로 쓰여, iOS 홈 화면이 틴트·클리어이면
/// 시스템이 걷어 내고 Liquid Glass 로 바꾼다. 어떤 모습이 될지는 iOS 홈 화면 설정만 정한다.
struct DesignBackground: View {
    let design: WidgetDesign
    var photo: UIImage?
    var family: WidgetFamily = .systemSmall

    var body: some View {
        ZStack {
            if design.useGradient {
                LinearGradient(colors: [Color(hex: design.backgroundHex), Color(hex: design.gradientHex)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                Color(hex: design.backgroundHex)
            }
            if design.template.usesImage, let photo {
                WidgetImageView(image: photo, layout: design.imageLayout(for: family))
                Color.black.opacity(design.photoDimming)
            }
        }
    }
}

/// 틴트·클리어 홈 화면에서 사진 템플릿은 배경이 걷히므로, 사진을 내용 층으로 올려
/// 시스템이 유리 위에 채도를 뺀 강조색으로 그리게 한다.
struct GlassPhotoLayer: View {
    let photo: UIImage
    var layout = WidgetImageLayout()

    var body: some View {
        WidgetImageView(image: photo, layout: layout, glass: true)
    }
}

// MARK: - 내용

struct DesignContent: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let date: Date
    /// iOS 홈 화면이 틴트·클리어일 때(widgetRenderingMode == .accented). 사용자 글자 색 대신
    /// 단색으로 그리고, 강조 그룹만 또렷하게 둔다. 앱 안에서는 항상 false.
    var glass = false
    var activity = WidgetActivity()
    var widgetControls = false
    var layoutSize: CGSize?
    var onAction: ((WidgetAction, UUID?) -> Void)?

    private var isSmall: Bool { family == .systemSmall }
    private var scale: CGFloat {
        switch family {
        case .systemLarge, .systemExtraLarge: return 1.5
        default: return 1
        }
    }
    private var textColor: Color { glass ? .white : Color(hex: design.textHex) }
    /// 유리 모드에서 강조가 아닌 글자는 한 단계 흐리게.
    private var secondaryOpacity: Double { glass ? 0.62 : 0.8 }

    var body: some View {
        Group {
            switch design.template {
            case .text: textBody
            case .clock: clockBody
            case .countdown: countdownBody
            case .photo, .gif: photoBody
            case .checklist, .counter, .focus, .pomodoro, .calendar:
                InteractiveDesignContent(design: design, family: family, date: date,
                                         activity: activity, widgetControls: widgetControls,
                                         layoutSize: layoutSize, onAction: onAction)
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

/// 홈 화면 위젯(기본 모드)과 같은 크기 비율로 디자인을 그려 보여 준다.
struct DesignPreviewCard: View {
    @Environment(\.scenePhase) private var scenePhase
    let design: WidgetDesign
    var family: WidgetFamily = .systemSmall
    var photo: UIImage?
    var date: Date?
    var maxWidth: CGFloat?
    var interactive = false
    @State private var activity = WidgetActivity()

    static let cornerRadius: CGFloat = 24

    static func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemMedium: return CGSize(width: 338, height: 158)
        case .systemLarge: return CGSize(width: 338, height: 354)
        case .systemExtraLarge: return CGSize(width: 720, height: 354)
        default: return CGSize(width: 158, height: 158)
        }
    }

    var body: some View {
        let size = Self.size(for: family)
        let scale = min(1, (maxWidth ?? size.width) / size.width)
        // 포모도로는 단계 경계를 초마다 확인하고, 시계·D-day는 분 경계에서 갱신한다.
        let minute = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        TimelineView(.periodic(from: minute, by: design.template == .pomodoro ? 1 : 60)) { context in
            DesignContent(design: design, family: family, date: date ?? context.date, activity: activity,
                          onAction: { action, item in activity.apply(action, to: design, itemID: item) })
                .padding(16)
        }
        .frame(width: size.width, height: size.height)
        .background(DesignBackground(design: design, photo: photo, family: family))
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        .scaleEffect(scale)
        .frame(width: size.width * scale, height: size.height * scale)
        .allowsHitTesting(interactive)
        .accessibilityHidden(!interactive)
        .task(id: design.id) { activity = DesignStore.loadActivity(for: design.id) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { activity = DesignStore.loadActivity(for: design.id) }
        }
        .onChange(of: design.focusMinutes) { _, _ in
            if !activity.timerIsRunning(at: .now) { activity.pausedSeconds = nil }
        }
    }
}

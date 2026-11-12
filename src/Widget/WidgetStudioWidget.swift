import AppIntents
import SwiftUI
import WidgetKit

// MARK: - 위젯 편집 화면에서 고르는 디자인

struct DesignEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "디자인"
    static var defaultQuery = DesignQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ design: WidgetDesign) {
        id = design.id
        name = design.name
    }
}

struct DesignQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [DesignEntity] {
        DesignStore.load().filter { identifiers.contains($0.id) }.map(DesignEntity.init)
    }

    func suggestedEntities() async throws -> [DesignEntity] {
        DesignStore.load().map(DesignEntity.init)
    }

    func defaultResult() async -> DesignEntity? {
        DesignStore.load().first.map(DesignEntity.init)
    }
}

struct SelectDesignIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "디자인 선택"
    static var description = IntentDescription("위젯에 보여 줄 디자인을 고릅니다.")

    @Parameter(title: "디자인")
    var design: DesignEntity?
}

// MARK: - 타임라인

struct DesignEntry: TimelineEntry {
    let date: Date
    let design: WidgetDesign?
}

struct DesignProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DesignEntry {
        DesignEntry(date: .now, design: WidgetDesign.samples[0])
    }

    func snapshot(for configuration: SelectDesignIntent, in context: Context) async -> DesignEntry {
        DesignEntry(date: .now, design: resolve(configuration) ?? WidgetDesign.samples[0])
    }

    func timeline(for configuration: SelectDesignIntent, in context: Context) async -> Timeline<DesignEntry> {
        let design = resolve(configuration)
        let now = Date.now
        let cal = Calendar.current

        guard let design else {
            return Timeline(entries: [DesignEntry(date: now, design: nil)], policy: .never)
        }

        switch design.template {
        case .clock:
            // 다음 60분을 분 단위 항목으로 미리 만들어 둔다.
            let startOfMinute = cal.date(bySetting: .second, value: 0, of: now) ?? now
            let base = startOfMinute > now ? cal.date(byAdding: .minute, value: -1, to: startOfMinute)! : startOfMinute
            let entries = (0..<60).compactMap { offset -> DesignEntry? in
                guard let d = cal.date(byAdding: .minute, value: offset, to: base) else { return nil }
                return DesignEntry(date: d, design: design)
            }
            return Timeline(entries: entries, policy: .atEnd)
        case .countdown:
            // 자정마다 D-day 숫자가 바뀐다.
            var entries = [DesignEntry(date: now, design: design)]
            var day = cal.startOfDay(for: now)
            for _ in 0..<7 {
                day = cal.date(byAdding: .day, value: 1, to: day)!
                entries.append(DesignEntry(date: day, design: design))
            }
            return Timeline(entries: entries, policy: .atEnd)
        case .text, .photo:
            return Timeline(entries: [DesignEntry(date: now, design: design)], policy: .never)
        }
    }

    private func resolve(_ configuration: SelectDesignIntent) -> WidgetDesign? {
        let all = DesignStore.load()
        if let id = configuration.design?.id, let match = all.first(where: { $0.id == id }) {
            return match
        }
        return all.first
    }
}

// MARK: - 뷰

struct WidgetStudioEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: DesignEntry

    /// 홈 화면이 틴트·클리어(Liquid Glass)이면 accented 로 그려진다.
    private var isGlass: Bool { renderingMode != .fullColor }

    var body: some View {
        if let design = entry.design {
            let photo = design.template == .photo ? DesignStore.loadPhoto(for: design.id) : nil
            ZStack {
                // 유리 모드에서는 배경이 걷히므로 사진을 내용 층에 올려 유리 위에 단색으로 남긴다.
                if isGlass, let photo {
                    GlassPhotoLayer(photo: photo)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .opacity(0.9)
                }
                DesignContent(design: design, family: family, date: entry.date, glass: isGlass)
                    .padding(16)
            }
            .containerBackground(for: .widget) {
                DesignBackground(design: design, photo: photo)
            }
            .widgetURL(URL(string: "widgetstudio://design/\(design.id.uuidString)"))
        } else {
            VStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.title2)
                    .widgetAccentable()
                Text("앱에서 디자인을\n만들어 주세요")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct WidgetStudioWidget: Widget {
    let kind = "WidgetStudioWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectDesignIntent.self, provider: DesignProvider()) { entry in
            WidgetStudioEntryView(entry: entry)
        }
        .configurationDisplayName("위젯 스튜디오")
        .description("앱에서 만든 디자인을 홈 화면에 놓습니다. 길게 눌러 디자인을 바꿀 수 있어요.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // 사진을 가장자리까지 채우기 위해 시스템 여백을 끄고 내용에 직접 16pt 를 준다.
        .contentMarginsDisabled()
    }
}

@main
struct WidgetStudioWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetStudioWidget()
    }
}

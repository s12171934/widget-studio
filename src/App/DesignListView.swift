import SwiftUI

struct DesignListView: View {
    @Environment(DesignLibrary.self) private var library
    @State private var sheet: Sheet?
    @AppStorage("wallpaper") private var wallpaper: Wallpaper.Style = .dusk

    private let columns = [GridItem(.adaptive(minimum: 158), spacing: 18)]

    private enum Sheet: Identifiable {
        case editor(WidgetDesign), player(WidgetDesign), guide
        var id: String {
            switch self {
            case .editor(let design): return "edit-\(design.id)"
            case .player(let design): return "play-\(design.id)"
            case .guide: return "guide"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if library.designs.isEmpty {
                        ContentUnavailableView("디자인이 없습니다", systemImage: "paintpalette",
                                               description: Text("아래 + 로 첫 위젯을 만들어 보세요."))
                            .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 22) {
                            ForEach(library.designs) { design in
                                card(design)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Wallpaper(style: wallpaper))
            .navigationTitle("위젯 스튜디오")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("홈 화면에 놓는 법", systemImage: "questionmark") { sheet = .guide }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("배경화면", selection: $wallpaper) {
                            ForEach(Wallpaper.Style.allCases) { Text($0.label).tag($0) }
                        }
                    } label: {
                        Label("배경화면", systemImage: "photo.artframe")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                CreateBar { template in sheet = .editor(.blank(template)) }
                    .padding(.bottom, 8)
            }
            .sheet(item: $sheet) { item in
                switch item {
                case .editor(let design):
                    DesignEditorView(design: design, wallpaper: wallpaper) { saved in library.upsert(saved) }
                case .player(let design): GIFPlayerScreen(design: design)
                case .guide: GuideView()
                }
            }
            .alert("작업을 완료할 수 없습니다", isPresented: Binding(
                get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { library.errorMessage = nil }
            } message: { Text(library.errorMessage ?? "") }
            .preferredColorScheme(wallpaper.colorScheme)
            .task {
                // 개발용: `simctl launch … -openDesign <UUID>` 로 편집 화면을 바로 연다.
                if let raw = UserDefaults.standard.string(forKey: "openDesign"),
                   let id = UUID(uuidString: raw) {
                    try? await Task.sleep(for: .milliseconds(600))
                    if let design = library.designs.first(where: { $0.id == id }) { sheet = .editor(design) }
                }
            }
            .onOpenURL { url in
                // widgetstudio://design/<UUID> — 위젯을 누르면 그 디자인 편집으로 연다.
                guard url.scheme == "widgetstudio", ["design", "play"].contains(url.host ?? ""),
                      let id = UUID(uuidString: url.lastPathComponent),
                      let design = library.designs.first(where: { $0.id == id }) else { return }
                if url.host == "play", design.template == .gif {
                    sheet = .player(design)
                } else {
                    sheet = .editor(design)
                }
            }
        }
    }

    private func card(_ design: WidgetDesign) -> some View {
        Button { sheet = .editor(design) } label: {
            VStack(spacing: 10) {
                DesignPreviewCard(design: design,
                                  photo: DesignStore.loadPhoto(for: design.id))
                Text(design.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("design-\(design.id.uuidString)")
        .contextMenu {
            if design.template == .gif {
                Button("GIF 재생", systemImage: "play.fill") { sheet = .player(design) }
            }
            Button("복제", systemImage: "plus.square.on.square") { library.duplicate(design) }
            Button("삭제", systemImage: "trash", role: .destructive) {
                if let i = library.designs.firstIndex(of: design) {
                    library.delete(at: IndexSet(integer: i))
                }
            }
        }
    }
}

// MARK: - 하단 만들기 막대

/// + 유리 방울을 누르면 템플릿 방울들이 그 안에서 녹아 나오듯 펼쳐진다.
struct CreateBar: View {
    let onPick: (WidgetDesign.Template) -> Void
    @State private var expanded = false
    @Namespace private var ns

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 12) {
                if expanded {
                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        ForEach(0..<((WidgetDesign.Template.allCases.count + 2) / 3), id: \.self) { row in
                            GridRow {
                                ForEach(Array(WidgetDesign.Template.allCases.dropFirst(row * 3).prefix(3))) { t in
                                    templateButton(t)
                                }
                            }
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Button {
                    withAnimation(.bouncy(duration: 0.4)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "xmark" : "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 58, height: 58)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
                .glassEffectID("toggle", in: ns)
                .accessibilityLabel(expanded ? "닫기" : "새 디자인")
            }
            .frame(maxWidth: expanded ? 480 : 58)
            .padding(.horizontal, expanded ? 12 : 0)
        }
        .padding(.horizontal, 16)
    }

    private func templateButton(_ template: WidgetDesign.Template) -> some View {
        Button {
            onPick(template)
            withAnimation(.bouncy) { expanded = false }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: template.symbol).font(.title3)
                Text(template.label).font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(template.label)
        .accessibilityIdentifier("create-\(template.rawValue)")
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }
}

extension WidgetDesign {
    static func blank(_ template: Template) -> WidgetDesign {
        switch template {
        case .text:
            return WidgetDesign(name: "새 문구", template: .text, title: "문구를 입력하세요")
        case .clock:
            return WidgetDesign(name: "새 시계", template: .clock, title: "")
        case .countdown:
            return WidgetDesign(name: "새 D-day", template: .countdown, title: "기념일")
        case .photo:
            return WidgetDesign(name: "새 사진", template: .photo, title: "", alignment: .leading)
        case .gif:
            return WidgetDesign(name: "새 GIF", template: .gif, title: "", alignment: .leading)
        case .checklist:
            return WidgetDesign(name: "새 체크리스트", template: .checklist, title: "오늘의 할 일",
                                checklistItems: [ChecklistItem(title: "물 마시기"), ChecklistItem(title: "책 읽기"),
                                                 ChecklistItem(title: "산책하기")])
        case .counter:
            return WidgetDesign(name: "새 카운터", template: .counter, title: "오늘의 기록")
        case .focus:
            return WidgetDesign(name: "새 집중 타이머", template: .focus, title: "지금은 집중할 시간")
        case .pomodoro:
            return WidgetDesign(name: "새 포모도로", template: .pomodoro, title: "집중과 휴식", pomodoroAppearance: .dial)
        case .calendar:
            return WidgetDesign(name: "새 월간 달력", template: .calendar, title: "오늘")
        }
    }
}

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("홈 화면에 추가") {
                    Label("홈 화면의 빈 곳을 길게 누릅니다.", systemImage: "1.circle")
                    Label("왼쪽 위 「편집」→「위젯 추가」를 누릅니다.", systemImage: "2.circle")
                    Label("「위젯 스튜디오」를 찾아 크기를 고르고 추가합니다.", systemImage: "3.circle")
                }
                Section("보여 줄 디자인 바꾸기") {
                    Label("놓은 위젯을 길게 눌러 「위젯 편집」을 고릅니다.", systemImage: "hand.tap")
                    Label("「디자인」에서 이 앱에서 만든 디자인을 고릅니다.", systemImage: "paintpalette")
                }
                Section("GIF 위젯") {
                    Label("GIF 편집기의 「프리셋에서 고르기」에서 8가지 장면을 바로 사용할 수 있습니다. 「GIF 검색·다운로드」에서는 검색 사이트를 열고 저장한 파일을 가져올 수 있습니다.", systemImage: "square.grid.2x2")
                    Label("+ 에서 GIF를 골라 사진 보관함이나 파일에서 가져옵니다. 12MB·300프레임 이하의 GIF를 사용할 수 있습니다.", systemImage: "photo.on.rectangle")
                    Label("홈 화면에서는 16장면·2초 루프로 반복 재생합니다. 위젯을 누르면 앱에서 원본을 재생합니다.", systemImage: "play.rectangle")
                }
                Section("버튼으로 조작하는 위젯") {
                    Label("체크리스트는 항목을 눌러 완료·취소하고, 카운터는 +·−·초기화로 값을 바꿉니다.", systemImage: "hand.tap")
                    Label("집중 타이머는 시작·일시 정지·초기화가 가능합니다. 앱을 열지 않고 조작하며, 종료 알림은 울리지 않습니다.", systemImage: "timer")
                    Label("포모도로는 집중·짧은 휴식을 반복하고 설정한 횟수마다 긴 휴식으로 바뀝니다. 홈 화면에서 시작·정지·재개·초기화하며 완료 횟수도 표시합니다.", systemImage: "timer.circle")
                }
                Section("크기") {
                    Label("작게·중간·크게는 iPhone과 iPad에서 사용할 수 있습니다. X-large는 iPad 홈 화면용입니다.", systemImage: "rectangle.expand.vertical")
                    Label("iPhone에서도 X-large 디자인을 미리 보고 크기별 사진·GIF 배치를 설정할 수 있습니다.", systemImage: "ipad.and.iphone")
                }
                Section("투명(Liquid Glass) 위젯") {
                    Label("위젯의 모습은 iOS 홈 화면 설정만 따릅니다. 홈 화면 「편집」→「사용자화」에서 클리어·틴트를 고르면 위젯 배경이 유리로 바뀝니다.",
                          systemImage: "drop")
                    Label("이때 시각·D-day 숫자·제목은 또렷하게, 나머지 글자는 흐리게 그려집니다.",
                          systemImage: "eye")
                }
            }
            .navigationTitle("사용법")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

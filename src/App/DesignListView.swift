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
            HStack(spacing: 8) {
                if expanded {
                    ForEach(WidgetDesign.Template.allCases) { t in
                        Button {
                            onPick(t)
                            withAnimation(.bouncy) { expanded = false }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: t.symbol).font(.title3)
                                Text(t.label).font(.caption2.weight(.medium))
                            }
                            .frame(width: 50, height: 58)
                            .contentShape(.rect(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(t.label)
                        .accessibilityIdentifier("create-\(t.rawValue)")
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                        .glassEffectID(t.rawValue, in: ns)
                    }
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
        }
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
                    Label("+ 에서 GIF를 골라 사진 보관함이나 파일에서 가져옵니다. 12MB·300프레임 이하의 GIF를 사용할 수 있습니다.", systemImage: "photo.on.rectangle")
                    Label("홈 화면에는 첫 장면이 표시되고, 위젯을 누르면 앱에서 반복 재생합니다. 앱의 디자인을 길게 눌러서도 재생할 수 있습니다.", systemImage: "play.rectangle")
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

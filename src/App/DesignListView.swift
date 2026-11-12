import SwiftUI

struct DesignListView: View {
    @Environment(DesignLibrary.self) private var library
    @State private var editing: WidgetDesign?
    @State private var showGuide = false
    @AppStorage("wallpaper") private var wallpaper: Wallpaper.Style = .dusk

    private let columns = [GridItem(.adaptive(minimum: 158), spacing: 18)]

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
                    Button("홈 화면에 놓는 법", systemImage: "questionmark") { showGuide = true }
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
                CreateBar { template in editing = .blank(template) }
                    .padding(.bottom, 8)
            }
            .sheet(item: $editing) { design in
                DesignEditorView(design: design, wallpaper: wallpaper) { saved in library.upsert(saved) }
            }
            .sheet(isPresented: $showGuide) { GuideView() }
            .preferredColorScheme(wallpaper.colorScheme)
            .task {
                // 개발용: `simctl launch … -openDesign <UUID>` 로 편집 화면을 바로 연다.
                if let raw = UserDefaults.standard.string(forKey: "openDesign"),
                   let id = UUID(uuidString: raw) {
                    try? await Task.sleep(for: .milliseconds(600))
                    editing = library.designs.first { $0.id == id }
                }
            }
            .onOpenURL { url in
                // widgetstudio://design/<UUID> — 위젯을 누르면 그 디자인 편집으로 연다.
                guard url.host == "design",
                      let id = UUID(uuidString: url.lastPathComponent),
                      let design = library.designs.first(where: { $0.id == id }) else { return }
                editing = design
            }
        }
    }

    private func card(_ design: WidgetDesign) -> some View {
        Button { editing = design } label: {
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
        .contextMenu {
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
            HStack(spacing: 10) {
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
                            .frame(width: 62, height: 58)
                            .contentShape(.rect(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
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

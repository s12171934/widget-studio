import SwiftUI

struct DesignListView: View {
    @Environment(DesignLibrary.self) private var library
    @State private var editing: WidgetDesign?
    @State private var showGuide = false

    private let columns = [GridItem(.adaptive(minimum: 158), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if library.designs.isEmpty {
                    ContentUnavailableView("디자인이 없습니다", systemImage: "paintpalette",
                                           description: Text("오른쪽 위 + 로 첫 위젯을 만들어 보세요."))
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(library.designs) { design in
                            Button { editing = design } label: {
                                VStack(spacing: 8) {
                                    DesignPreviewCard(design: design,
                                                      photo: DesignStore.loadPhoto(for: design.id))
                                    Text(design.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
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
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("위젯 스튜디오")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("홈 화면에 놓는 법", systemImage: "questionmark.circle") { showGuide = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(WidgetDesign.Template.allCases) { t in
                            Button(t.label, systemImage: t.symbol) { editing = .blank(t) }
                        }
                    } label: {
                        Label("새 디자인", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { design in
                DesignEditorView(design: design) { saved in library.upsert(saved) }
            }
            .sheet(isPresented: $showGuide) { GuideView() }
            .task {
                // 개발용: `simctl launch … -openDesign <UUID>` 로 편집 화면을 바로 연다.
                if let raw = UserDefaults.standard.string(forKey: "openDesign"),
                   let id = UUID(uuidString: raw) {
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
                Section {
                    Text("앱에서 디자인을 저장하면 홈 화면 위젯도 곧바로 새로 그려집니다.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("사용법")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("닫기") { dismiss() } }
        }
    }
}

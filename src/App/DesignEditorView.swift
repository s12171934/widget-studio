import PhotosUI
import SwiftUI
import WidgetKit

struct DesignEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var design: WidgetDesign
    @State private var family: WidgetFamily = .systemSmall
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var photoChanged = false
    @State private var appearance: HomeAppearance = .standard
    // 유리(투명) 배경
    @State private var homeShot: UIImage? = DesignStore.loadWallpaper()
    @State private var shotItem: PhotosPickerItem?
    @State private var shotChanged = false
    @State private var placing: GlassFamily?
    @State private var liveGlass: UIImage?
    let wallpaper: Wallpaper.Style
    let onSave: (WidgetDesign) -> Void

    init(design: WidgetDesign, wallpaper: Wallpaper.Style = .dusk,
         onSave: @escaping (WidgetDesign) -> Void) {
        _design = State(initialValue: design)
        self.wallpaper = wallpaper
        _photo = State(initialValue: DesignStore.loadPhoto(for: design.id))
        self.onSave = onSave
    }

    private let palette = ["#0F172A", "#1E3A8A", "#7C3AED", "#DB2777", "#F97316",
                           "#FACC15", "#16A34A", "#0EA5E9", "#FEF3C7", "#FFFFFF"]

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                Section("기본") {
                    TextField("디자인 이름", text: $design.name)
                    Picker("템플릿", selection: $design.template) {
                        ForEach(WidgetDesign.Template.allCases) { t in
                            Label(t.label, systemImage: t.symbol).tag(t)
                        }
                    }
                }
                contentSection
                if design.template == .photo {
                    photoSection
                } else {
                    backgroundSection
                }
                Section("글자") {
                    ColorPicker("글자 색", selection: hexBinding(\.textHex), supportsOpacity: false)
                    Picker("글꼴", selection: $design.fontStyle) {
                        ForEach(WidgetDesign.FontStyle.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("정렬", selection: $design.alignment) {
                        ForEach(WidgetDesign.Alignment.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Wallpaper(style: wallpaper))
            .navigationTitle(design.name.isEmpty ? "디자인" : design.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", systemImage: "checkmark") { save() }
                        .buttonStyle(.glassProminent)
                }
            }
            .fullScreenCover(item: $placing) { f in
                if let homeShot {
                    GlassPlacementView(design: $design, family: f, wallpaper: homeShot)
                }
            }
            .task(id: glassRenderKey) { renderLiveGlass() }
            .onChange(of: shotItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    homeShot = image
                    shotChanged = true
                }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    photo = image.resized(maxSide: 1000)
                    photoChanged = true
                }
            }
        }
    }

    // MARK: 섹션

    /// 배경화면 위에 실제 크기의 위젯을 띄우고, 크기와 홈 화면 표시 방식을 유리 선택기로 바꾼다.
    private var previewSection: some View {
        Section {
            VStack(spacing: 16) {
                DesignPreviewCard(design: design, family: family, photo: photo,
                                  appearance: appearance, tint: wallpaper.homeTint, glass: liveGlass)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignPreviewCard.size(for: family).height)
                    .animation(.snappy, value: family)
                    .animation(.smooth, value: appearance)
                GlassSegmented(options: [WidgetFamily.systemSmall, .systemMedium, .systemLarge],
                               selection: $family) { f in
                    switch f {
                    case .systemMedium: return "중간"
                    case .systemLarge: return "크게"
                    default: return "작게"
                    }
                }
                VStack(spacing: 6) {
                    GlassSegmented(options: HomeAppearance.allCases, selection: $appearance,
                                   label: \.label, tint: .white.opacity(0.35))
                    Text("홈 화면 전체 설정(편집 > 사용자화) 미리보기 · 이 위젯만 투명하게 하려면 배경을 「유리(투명)」로")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        Section("내용") {
            switch design.template {
            case .text:
                TextField("문구", text: $design.title, axis: .vertical)
                TextField("보조 문구 (선택)", text: $design.subtitle)
            case .clock:
                TextField("시계 아래 한 줄 (선택)", text: $design.title)
            case .countdown:
                TextField("제목", text: $design.title)
                DatePicker("날짜", selection: $design.targetDate, displayedComponents: .date)
                LabeledContent("오늘 기준", value: design.dDayLabel(from: .now))
            case .photo:
                TextField("제목 (선택)", text: $design.title)
                TextField("보조 문구 (선택)", text: $design.subtitle)
            }
        }
    }

    private var backgroundSection: some View {
        Section {
            Picker("배경", selection: $design.backgroundStyle) {
                ForEach(WidgetDesign.BackgroundStyle.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            if design.backgroundStyle == .color {
                colorRows
            } else {
                glassRows
            }
        } header: {
            Text("배경")
        } footer: {
            if design.backgroundStyle == .glass {
                Text("iOS 는 위젯 하나만 클리어로 바꿀 수 없어서, 빈 홈 화면 스크린샷에서 위젯 자리를 잘라 유리처럼 깝니다. 배경화면을 바꾸면 스크린샷을 다시 넣어 주세요.")
            }
        }
    }

    @ViewBuilder
    private var colorRows: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(palette, id: \.self) { hex in
                        GlassSwatch(hex: hex, selected: design.backgroundHex == hex) {
                            design.backgroundHex = hex
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .scrollClipDisabled()
        ColorPicker("배경 색", selection: hexBinding(\.backgroundHex), supportsOpacity: false)
        Toggle("그라데이션", isOn: $design.useGradient)
        if design.useGradient {
            ColorPicker("두 번째 색", selection: hexBinding(\.gradientHex), supportsOpacity: false)
        }
    }

    @ViewBuilder
    private var glassRows: some View {
        PhotosPicker(selection: $shotItem, matching: .screenshots) {
            Label(homeShot == nil ? "빈 홈 화면 스크린샷 고르기" : "스크린샷 바꾸기", systemImage: "iphone")
        }
        if homeShot == nil {
            Text("홈 화면을 길게 눌러 편집 모드로 들어간 뒤, 아이콘이 없는 마지막 페이지로 넘겨 스크린샷을 찍으세요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        if let homeShot {
            if !GlassRenderer.matchesScreen(homeShot) {
                Label("이 아이폰 화면 비율과 다른 스크린샷이에요. 자리가 어긋날 수 있어요.",
                      systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            ForEach(GlassFamily.allCases) { f in
                Button { placing = f } label: {
                    LabeledContent("\(f.label) 위젯 자리 맞추기") {
                        if design.glassRects[f.rawValue] != nil {
                            Label("맞춤", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Text("아직")
                        }
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        Section("사진") {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photo == nil ? "사진 고르기" : "다른 사진으로 바꾸기", systemImage: "photo.on.rectangle")
            }
            VStack(alignment: .leading) {
                Text("어둡게 \(Int(design.photoDimming * 100))%")
                Slider(value: $design.photoDimming, in: 0...0.7)
            }
        }
    }

    // MARK: 동작

    private func hexBinding(_ keyPath: WritableKeyPath<WidgetDesign, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: design[keyPath: keyPath]) },
            set: { design[keyPath: keyPath] = $0.hexString }
        )
    }

    /// 미리보기 유리 그림을 다시 만들어야 하는 조건.
    private var glassRenderKey: String {
        let r = design.glassRects[family.glassFamily.rawValue]
        return "\(design.usesGlass)|\(family.glassFamily.rawValue)|\(String(describing: r))|\(design.glassBlur)|\(design.glassDim)|\(homeShot.map { ObjectIdentifier($0).hashValue } ?? 0)"
    }

    private func renderLiveGlass() {
        guard design.usesGlass, let homeShot,
              let rect = design.glassRects[family.glassFamily.rawValue] else {
            liveGlass = nil
            return
        }
        liveGlass = GlassRenderer.render(wallpaper: homeShot, rect: rect,
                                         blur: design.glassBlur, dim: design.glassDim, compensateFilm: false)
    }

    private func save() {
        if photoChanged, let photo {
            DesignStore.savePhoto(photo, for: design.id)
        }
        if shotChanged, let homeShot {
            // 스크린샷은 모든 디자인이 함께 쓴다 — 바뀌면 다른 유리 디자인도 다시 자른다.
            DesignStore.saveWallpaper(homeShot)
            for other in DesignStore.load() where other.id != design.id && other.usesGlass {
                GlassRenderer.renderAll(other, wallpaper: homeShot)
            }
        }
        GlassRenderer.renderAll(design, wallpaper: homeShot)
        if design.name.trimmingCharacters(in: .whitespaces).isEmpty {
            design.name = design.template.label
        }
        onSave(design)
        dismiss()
    }
}

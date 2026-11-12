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
    @State private var gif: GIFAsset?
    @State private var gifItem: PhotosPickerItem?
    @State private var gifChanged = false
    @State private var importingGIF = false
    @State private var showGIFFilePicker = false
    @State private var showGIFPlayer = false
    @State private var gifError: String?
    @State private var gifRequest = UUID()
    @State private var showGIFSources = false
    @State private var gifSourceTab: GIFSourceSheet.Tab = .presets
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
                if design.template == .gif {
                    gifSection
                } else if design.template == .photo {
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
                        .disabled(importingGIF || (design.template == .gif && gif == nil))
                        .accessibilityIdentifier("save-design")
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
            .task {
                guard design.template == .gif, DesignStore.design(id: design.id) != nil else { return }
                let id = design.id
                await loadGIF(changed: false) {
                    try await Task.detached(priority: .userInitiated) {
                        guard let data = DesignStore.loadGIFData(for: id) else { throw GIFAsset.ImportError.invalid }
                        return try GIFAsset(data: data)
                    }.value
                }
            }
            .task(id: gifItem) {
                guard let item = gifItem else { return }
                await loadGIF(changed: true) {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw GIFAsset.ImportError.invalid }
                    return try await Task.detached(priority: .userInitiated) { try GIFAsset(data: data) }.value
                }
            }
            .sheet(isPresented: $showGIFFilePicker) {
                GIFFilePicker { url in
                    showGIFFilePicker = false
                    Task {
                        await loadGIF(changed: true) {
                            try await Task.detached(priority: .userInitiated) { try GIFAsset.readFile(url) }.value
                        }
                    }
                } onCancel: { showGIFFilePicker = false }
            }
            .sheet(isPresented: $showGIFPlayer) {
                GIFPlayerScreen(design: design, preview: gif)
            }
            .sheet(isPresented: $showGIFSources) {
                GIFSourceSheet(initialTab: gifSourceTab) { preset, asset in
                    gifRequest = UUID()
                    importingGIF = false
                    gif = asset
                    photo = asset.poster
                    gifChanged = true
                    photoChanged = true
                    if let preset {
                        design.photoDimming = 0
                        if design.name == "새 GIF" || design.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            design.name = preset.title
                        }
                    }
                }
            }
            .alert("GIF 작업을 완료할 수 없습니다", isPresented: Binding(
                get: { gifError != nil }, set: { if !$0 { gifError = nil } }
            )) {
                Button("확인", role: .cancel) { gifError = nil }
            } message: { Text(gifError ?? "") }
            .onDisappear { gifRequest = UUID() }
        }
    }

    // MARK: 섹션

    /// 배경화면 위에 실제 크기의 위젯을 띄우고, 크기를 유리 선택기로 바꾼다.
    private var previewSection: some View {
        Section {
            VStack(spacing: 16) {
                DesignPreviewCard(design: design, family: family, photo: photo)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignPreviewCard.size(for: family).height)
                    .animation(.snappy, value: family)
                GlassSegmented(options: [WidgetFamily.systemSmall, .systemMedium, .systemLarge],
                               selection: $family) { f in
                    switch f {
                    case .systemMedium: return "중간"
                    case .systemLarge: return "크게"
                    default: return "작게"
                    }
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
            case .photo, .gif:
                TextField("제목 (선택)", text: $design.title)
                TextField("보조 문구 (선택)", text: $design.subtitle)
            }
        }
    }

    private var backgroundSection: some View {
        Section {
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
        } header: {
            Text("배경")
        } footer: {
            Text("iOS 홈 화면을 클리어·틴트로 두면 이 배경 대신 유리가 깔립니다.")
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

    private var gifSection: some View {
        Section {
            Button("프리셋에서 고르기", systemImage: "square.grid.2x2") {
                gifSourceTab = .presets
                showGIFSources = true
            }
            .accessibilityIdentifier("pick-gif-preset")
            Button("GIF 검색·다운로드", systemImage: "magnifyingglass") {
                gifSourceTab = .search
                showGIFSources = true
            }
            .accessibilityIdentifier("find-gif-online")
            PhotosPicker(selection: $gifItem, matching: .images, preferredItemEncoding: .current) {
                Label("사진 보관함에서 GIF 고르기", systemImage: "photo.on.rectangle")
            }
            .accessibilityIdentifier("pick-gif-photos")
            Button("파일에서 GIF 고르기", systemImage: "folder") { showGIFFilePicker = true }
            if importingGIF { ProgressView("GIF 가져오는 중") }
            if let gif {
                LabeledContent("GIF", value: "\(gif.delays.count)프레임 · \(gif.duration.formatted(.number.precision(.fractionLength(1))))초")
                    .accessibilityIdentifier("gif-metadata")
                Button("GIF 재생", systemImage: "play.fill") { showGIFPlayer = true }
                    .accessibilityIdentifier("preview-gif")
            }
            VStack(alignment: .leading) {
                Text("어둡게 \(Int(design.photoDimming * 100))%")
                Slider(value: $design.photoDimming, in: 0...0.7)
            }
        } header: { Text("GIF") }
        footer: {
            Text("홈 화면에는 첫 장면이 표시됩니다. 위젯을 누르면 앱에서 반복 재생합니다. GIF는 12MB·300프레임 이하로 골라 주세요.")
        }
    }

    // MARK: 동작

    @MainActor
    private func loadGIF(changed: Bool, make: () async throws -> GIFAsset) async {
        let request = UUID()
        gifRequest = request
        importingGIF = true
        defer { if gifRequest == request { importingGIF = false } }
        do {
            let loaded = try await make()
            guard !Task.isCancelled, gifRequest == request else { return }
            gif = loaded
            photo = loaded.poster
            if changed { gifChanged = true; photoChanged = true }
        } catch is CancellationError { }
        catch {
            if !Task.isCancelled, gifRequest == request { gifError = error.localizedDescription }
        }
    }

    private func hexBinding(_ keyPath: WritableKeyPath<WidgetDesign, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: design[keyPath: keyPath]) },
            set: { design[keyPath: keyPath] = $0.hexString }
        )
    }

    private func save() {
        do {
            if design.template == .gif {
                guard let gif else { return }
                if gifChanged { try DesignStore.saveGIF(gif, for: design.id) }
            } else {
                try DesignStore.deleteGIF(for: design.id)
                if photoChanged, let photo { DesignStore.savePhoto(photo, for: design.id) }
            }
        } catch {
            gifError = error.localizedDescription
            return
        }
        if design.name.trimmingCharacters(in: .whitespaces).isEmpty {
            design.name = design.template.label
        }
        onSave(design)
        dismiss()
    }
}

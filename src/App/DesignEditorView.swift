import PhotosUI
import SwiftUI
import WidgetKit

struct DesignEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var design: WidgetDesign
    @State private var family: WidgetFamily = .systemSmall
    @State private var previewWidth: CGFloat = 320
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
        _family = State(initialValue: design.template == .pomodoro && design.pomodoroAppearance == .dial ? .systemLarge : .systemSmall)
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
                if design.template.usesImage { imageLayoutSection }
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
                        .disabled(importingGIF || (design.template == .gif && gif == nil)
                                  || (design.template == .checklist && design.checklistItems.allSatisfy {
                                      $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  }))
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
            .onChange(of: design.template) { _, template in
                if template == .checklist, design.checklistItems.isEmpty {
                    design.checklistItems = [ChecklistItem(title: "첫 번째 할 일"), ChecklistItem(title: "두 번째 할 일")]
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

    private var imageLayoutSection: some View {
        Section {
            Picker("이미지 맞춤", selection: imageLayoutBinding(\.mode)) {
                ForEach(WidgetImageLayout.Mode.allCases) { mode in Text(mode.label).tag(mode) }
            }
            .pickerStyle(.segmented)
            LabeledContent("확대", value: "\(Int(design.imageLayout(for: family).zoom * 100))%")
            Slider(value: imageLayoutBinding(\.zoom), in: 1...3, step: 0.05)
                .accessibilityLabel("이미지 확대")
            LabeledContent("가로 위치", value: "\(Int(design.imageLayout(for: family).horizontal * 100))%")
            Slider(value: imageLayoutBinding(\.horizontal), in: -1...1, step: 0.05)
                .accessibilityLabel("이미지 가로 위치")
            LabeledContent("세로 위치", value: "\(Int(design.imageLayout(for: family).vertical * 100))%")
            Slider(value: imageLayoutBinding(\.vertical), in: -1...1, step: 0.05)
                .accessibilityLabel("이미지 세로 위치")
            Button("이 크기 초기화", systemImage: "arrow.counterclockwise") {
                design.imageLayouts.removeValue(forKey: family.studioSizeKey)
            }
        } header: {
            Text("\(family.studioSizeLabel) 위젯 화면")
        } footer: {
            Text("미리보기에서 크기를 선택해 각각 설정하세요. X-large도 별도로 저장하며, 사진과 GIF의 모든 장면에 같은 표시 범위를 적용합니다.")
        }
    }

    private func imageLayoutBinding<Value>(_ keyPath: WritableKeyPath<WidgetImageLayout, Value>) -> Binding<Value> {
        let key = family.studioSizeKey
        return Binding(
            get: { (design.imageLayouts[key] ?? WidgetImageLayout())[keyPath: keyPath] },
            set: { value in
                var layout = design.imageLayouts[key] ?? WidgetImageLayout()
                layout[keyPath: keyPath] = value
                design.imageLayouts[key] = layout
            }
        )
    }

    /// 배경화면 위에 실제 크기의 위젯을 띄우고, 크기를 유리 선택기로 바꾼다.
    private var previewSection: some View {
        Section {
            VStack(spacing: 16) {
                if design.template == .pomodoro {
                    GlassSegmented(options: WidgetDesign.PomodoroAppearance.allCases,
                                   selection: $design.pomodoroAppearance) { $0.label }
                        .accessibilityIdentifier("pomodoro-appearance")
                }
                DesignPreviewCard(design: design, family: family, photo: photo,
                                  maxWidth: previewWidth, interactive: true)
                    .frame(maxWidth: .infinity)
                    .animation(.snappy, value: family)
                GlassSegmented(options: [WidgetFamily.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge],
                               selection: $family) { $0.studioSizeLabel }
                    .accessibilityIdentifier("widget-size-picker")
                if family == .systemExtraLarge {
                    Text("X-large는 iPad 홈 화면에서 사용할 수 있습니다. iPhone은 작게·중간·크게를 지원합니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if design.template.isInteractive {
                    Text("버튼을 눌러 미리 체험하세요. 미리보기 조작은 홈 화면의 기록을 바꾸지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { previewWidth = max(1, $0) }
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
            case .checklist:
                TextField("제목", text: $design.title)
                ForEach($design.checklistItems) { $item in
                    TextField("할 일", text: $item.title)
                        .accessibilityIdentifier("checklist-item-\(item.id.uuidString)")
                }
                .onDelete { design.checklistItems.remove(atOffsets: $0) }
                .onMove { design.checklistItems.move(fromOffsets: $0, toOffset: $1) }
                Button("할 일 추가", systemImage: "plus") {
                    design.checklistItems.append(ChecklistItem(title: ""))
                }
                .disabled(design.checklistItems.count >= 20)
                .accessibilityIdentifier("add-checklist-item")
                Text("최대 20개 · 왼쪽으로 밀어 삭제합니다. 작은 위젯은 2개, 크게는 7개, X-large는 14개를 보여 줍니다.")
                    .font(.caption).foregroundStyle(.secondary)
            case .counter:
                TextField("제목", text: $design.title)
                TextField("보조 문구 (선택)", text: $design.subtitle)
                LabeledContent("시작 값") {
                    TextField("0", value: $design.counterStart, format: .number)
                        .multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation)
                }
                Stepper("한 번에 \(design.counterStep)", value: $design.counterStep, in: 1...1000)
                Stepper("목표 \(design.counterGoal)", value: $design.counterGoal, in: 1...100_000)
                Text("홈 화면에서 +·−로 세고 초기화 버튼으로 시작 값으로 돌아갑니다.")
                    .font(.caption).foregroundStyle(.secondary)
            case .focus:
                TextField("제목", text: $design.title)
                TextField("보조 문구 (선택)", text: $design.subtitle)
                Stepper("집중 시간 \(design.focusMinutes)분", value: $design.focusMinutes, in: 1...180)
                Text("홈 화면에서 시작·일시 정지·초기화할 수 있습니다. 남은 시간을 표시하며, 종료 알림은 울리지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            case .pomodoro:
                TextField("제목", text: $design.title)
                TextField("보조 문구 (선택)", text: $design.subtitle)
                Stepper("집중 \(design.pomodoroSettings.focusMinutes)분", value: $design.pomodoroSettings.focusMinutes, in: 1...180)
                    .accessibilityIdentifier("pomodoro-focus-minutes")
                Stepper("짧은 휴식 \(design.pomodoroSettings.shortBreakMinutes)분", value: $design.pomodoroSettings.shortBreakMinutes, in: 1...60)
                    .accessibilityIdentifier("pomodoro-short-break")
                Stepper("긴 휴식 \(design.pomodoroSettings.longBreakMinutes)분", value: $design.pomodoroSettings.longBreakMinutes, in: 1...120)
                    .accessibilityIdentifier("pomodoro-long-break")
                Stepper("\(design.pomodoroSettings.rounds)회마다 긴 휴식", value: $design.pomodoroSettings.rounds, in: 1...12)
                    .accessibilityIdentifier("pomodoro-rounds")
                Text("집중과 휴식이 자동으로 반복됩니다. 실행 중인 주기의 시간은 유지하며 변경한 설정은 초기화 후 적용됩니다. 종료 알림은 울리지 않습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            case .calendar:
                TextField("제목 (X-large)", text: $design.title)
                TextField("보조 문구 (X-large, 선택)", text: $design.subtitle)
                Text("이번 달과 오늘 날짜를 보여 주며 자정에 날짜가 바뀝니다.")
                    .font(.caption).foregroundStyle(.secondary)
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
            Text("저장하면 앱을 열지 않아도 홈 화면 위젯에서 반복 재생됩니다. 위젯용으로 16장면·2초 루프로 변환하며 원본 GIF는 그대로 보관합니다. 12MB·300프레임 이하로 골라 주세요.")
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
        if design.template == .checklist {
            design.checklistItems = Array(design.checklistItems.compactMap { item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return title.isEmpty ? nil : ChecklistItem(id: item.id, title: title)
            }.prefix(20))
            guard !design.checklistItems.isEmpty else { return }
        }
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

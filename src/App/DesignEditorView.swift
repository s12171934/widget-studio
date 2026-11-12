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
    let onSave: (WidgetDesign) -> Void

    init(design: WidgetDesign, onSave: @escaping (WidgetDesign) -> Void) {
        _design = State(initialValue: design)
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
            .navigationTitle(design.name.isEmpty ? "디자인" : design.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }.bold()
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

    private var previewSection: some View {
        Section {
            VStack(spacing: 14) {
                DesignPreviewCard(design: design, family: family, photo: photo)
                    .frame(maxWidth: .infinity)
                    .animation(.snappy, value: family)
                Picker("크기", selection: $family) {
                    Text("작게").tag(WidgetFamily.systemSmall)
                    Text("중간").tag(WidgetFamily.systemMedium)
                    Text("크게").tag(WidgetFamily.systemLarge)
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
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
        Section("배경") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(.secondary.opacity(0.4), lineWidth: 1))
                            .overlay {
                                if design.backgroundHex == hex {
                                    Image(systemName: "checkmark").font(.caption.bold())
                                        .foregroundStyle(hex == "#FFFFFF" || hex == "#FEF3C7" || hex == "#FACC15" ? .black : .white)
                                }
                            }
                            .onTapGesture { design.backgroundHex = hex }
                    }
                }
                .padding(.vertical, 4)
            }
            ColorPicker("배경 색", selection: hexBinding(\.backgroundHex), supportsOpacity: false)
            Toggle("그라데이션", isOn: $design.useGradient)
            if design.useGradient {
                ColorPicker("두 번째 색", selection: hexBinding(\.gradientHex), supportsOpacity: false)
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

    private func save() {
        if photoChanged, let photo {
            DesignStore.savePhoto(photo, for: design.id)
        }
        if design.name.trimmingCharacters(in: .whitespaces).isEmpty {
            design.name = design.template.label
        }
        onSave(design)
        dismiss()
    }
}

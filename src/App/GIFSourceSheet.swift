import SwiftUI

enum GIFSearchProvider: String, CaseIterable, Identifiable {
    case pixabay, giphy, tenor
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pixabay: return "Pixabay"
        case .giphy: return "GIPHY"
        case .tenor: return "Tenor"
        }
    }
    var detail: String {
        switch self {
        case .pixabay: return "다운로드 메뉴가 있는 GIF 모음"
        case .giphy: return "다양한 테마와 반응 GIF"
        case .tenor: return "짧은 반응·스티커 GIF"
        }
    }

    func searchURL(query: String) -> URL {
        let words = query.split(whereSeparator: \.isWhitespace)
        let phrase = words.joined(separator: self == .pixabay ? " " : "-")
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#%")
        let encoded = phrase.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        var components = URLComponents()
        components.scheme = "https"
        switch self {
        case .pixabay:
            components.host = "pixabay.com"
            components.percentEncodedPath = encoded.isEmpty ? "/gifs/" : "/gifs/search/\(encoded)/"
        case .giphy:
            components.host = "giphy.com"
            components.percentEncodedPath = encoded.isEmpty ? "/" : "/explore/\(encoded)"
        case .tenor:
            components.host = "tenor.com"
            components.percentEncodedPath = encoded.isEmpty ? "/" : "/search/\(encoded)-gifs"
        }
        return components.url!
    }
}

struct GIFSourceSheet: View {
    enum Tab: String, CaseIterable, Identifiable {
        case presets, search
        var id: String { rawValue }
        var label: String { self == .presets ? "프리셋" : "GIF 찾기" }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab
    @State private var query = ""
    @State private var posters: [GIFPreset: UIImage] = [:]
    @State private var importing: GIFPreset?
    @State private var generation: Task<Void, Never>?
    @State private var message: String?
    @State private var showFilePicker = false
    @State private var importingFile = false
    @FocusState private var searchFocused: Bool
    let onSelect: (GIFPreset?, GIFAsset) -> Void

    init(initialTab: Tab, onSelect: @escaping (GIFPreset?, GIFAsset) -> Void) {
        _tab = State(initialValue: initialTab)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GlassSegmented(options: Tab.allCases, selection: $tab) { $0.label }
                    .disabled(importing != nil || importingFile)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                if tab == .presets { presetGrid } else { searchForm }
            }
            .background(Wallpaper(style: .dusk))
            .navigationTitle("GIF 라이브러리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                }
            }
            .overlay {
                if importing != nil || importingFile {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().tint(.white)
                            Text("\(importing?.title ?? "GIF") 준비 중").font(.subheadline)
                        }
                        .foregroundStyle(.white)
                        .padding(24)
                        .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    }
                    .allowsHitTesting(false)
                }
            }
            .alert("GIF를 열 수 없습니다", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("확인", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
            .sheet(isPresented: $showFilePicker) {
                GIFFilePicker { url in
                    showFilePicker = false
                    loadAsset(preset: nil) { try GIFAsset.readFile(url) }
                } onCancel: { showFilePicker = false }
            }
            .task {
                guard posters.isEmpty else { return }
                let loaded = await Task.detached(priority: .userInitiated) {
                    Dictionary(uniqueKeysWithValues: GIFPreset.allCases.map { ($0, $0.render()) })
                }.value
                if !Task.isCancelled { posters = loaded }
            }
            .onDisappear { generation?.cancel() }
            .preferredColorScheme(.dark)
        }
    }

    private var presetGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("마음에 드는 장면을 골라 바로 시작하세요.")
                    .font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(GIFPreset.allCases) { preset in
                        Button { select(preset) } label: {
                            ZStack(alignment: .bottomLeading) {
                                if let poster = posters[preset] {
                                    Image(uiImage: poster).resizable().scaledToFill()
                                } else {
                                    Color.indigo.opacity(0.3)
                                }
                                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.title).font(.subheadline.weight(.bold))
                                    Text(preset.subtitle).font(.caption2).opacity(0.8)
                                }
                                .foregroundStyle(.white).padding(12)
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        .disabled(importing != nil || importingFile)
                        .accessibilityLabel("\(preset.title), \(preset.subtitle)")
                        .accessibilityIdentifier("preset-\(preset.id)")
                    }
                }
                Text("프리셋은 오프라인으로 사용할 수 있습니다. 홈 화면에서는 첫 장면이 표시되고, 위젯을 누르면 앱에서 반복 재생합니다.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private var searchForm: some View {
        Form {
            Section("검색어") {
                TextField("예: 고양이, 반짝이, ocean", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($searchFocused)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("gif-search-query")
            }
            Section {
                ForEach(GIFSearchProvider.allCases) { provider in
                    Link(destination: provider.searchURL(query: query)) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(provider.title)에서 검색").font(.body.weight(.medium))
                                Text(provider.detail).font(.caption).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square").foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("gif-search-\(provider.id)")
                }
            } header: { Text("검색 사이트") }
            footer: {
                Text("사이트가 브라우저에서 열립니다. 원하는 GIF의 다운로드 메뉴나 이미지 저장 기능으로 파일을 저장해 주세요. 사이트에 따라 저장 방법이 다를 수 있습니다.")
            }
            Section {
                Button("다운로드한 GIF 불러오기", systemImage: "square.and.arrow.down") { showFilePicker = true }
                    .accessibilityIdentifier("import-downloaded-gif")
            } footer: {
                Text("파일 앱에 저장한 GIF를 가져옵니다. 사진 보관함에 저장했다면 편집기의 사진 보관함 버튼을 이용해 주세요.")
            }
        }
        .scrollContentBackground(.hidden)
        .disabled(importingFile)
    }

    private func select(_ preset: GIFPreset) {
        loadAsset(preset: preset) { try preset.makeAsset() }
    }

    private func loadAsset(preset: GIFPreset?, make: @escaping @Sendable () throws -> GIFAsset) {
        generation?.cancel()
        importing = preset
        importingFile = preset == nil
        generation = Task {
            defer { importing = nil; importingFile = false }
            do {
                let worker = Task.detached(priority: .userInitiated) { try make() }
                let asset = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                onSelect(preset, asset)
                dismiss()
            } catch is CancellationError { }
            catch { message = error.localizedDescription }
        }
    }
}

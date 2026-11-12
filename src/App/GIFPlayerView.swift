import SwiftUI

/// 위젯에서는 대표 장면을 보여 주고, 재생 링크로 이 앱 화면을 연다.
struct GIFPlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let design: WidgetDesign
    var preview: GIFAsset?
    @State private var asset: GIFAsset?
    @State private var message: String?
    @State private var playing = true

    var body: some View {
        NavigationStack {
            Group {
                if let message {
                    ContentUnavailableView("GIF를 열 수 없습니다", systemImage: "exclamationmark.triangle",
                                           description: Text(message))
                } else if let asset = preview ?? asset {
                    GIFPlaybackView(asset: asset, playing: playing && scenePhase == .active) {
                        message = GIFAsset.ImportError.invalid.localizedDescription
                    }
                        .accessibilityLabel("재생 중인 GIF")
                        .accessibilityIdentifier("gif-player")
                        .aspectRatio(asset.poster.size, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    ProgressView("GIF 여는 중")
                }
            }
            .background(Color.black)
            .navigationTitle(design.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    if preview != nil || asset != nil {
                        Button(playing ? "일시 정지" : "재생", systemImage: playing ? "pause.fill" : "play.fill") {
                            playing.toggle()
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .task {
                guard preview == nil, asset == nil else { return }
                do {
                    let id = design.id
                    let loaded = try await Task.detached(priority: .userInitiated) {
                        guard let data = DesignStore.loadGIFData(for: id) else { throw GIFAsset.ImportError.invalid }
                        return try GIFAsset(data: data)
                    }.value
                    try Task.checkCancellation()
                    asset = loaded
                } catch is CancellationError { }
                catch { message = error.localizedDescription }
            }
        }
    }
}

/// 화면에 보일 때만 재생한다. ImageIO 디코딩은 직렬 큐, 캐시는 최대 24MiB다.
private struct GIFPlaybackView: UIViewRepresentable {
    let asset: GIFAsset
    let playing: Bool
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        context.coordinator.view = view
        return view
    }
    func updateUIView(_ view: UIImageView, context: Context) {
        context.coordinator.onFailure = onFailure
        context.coordinator.update(asset, playing: playing)
    }
    static func dismantleUIView(_ view: UIImageView, coordinator: Coordinator) { coordinator.stop() }

    final class Coordinator: NSObject {
        weak var view: UIImageView?
        var onFailure: (() -> Void)?
        private var asset: GIFAsset?
        private var link: CADisplayLink?
        private var elapsed: TimeInterval = 0
        private var previousTimestamp: TimeInterval?
        private var displayedIndex = -1
        private var decoding = false
        private let queue = DispatchQueue(label: "widget-studio.gif-frames", qos: .userInitiated)
        private let cache = NSCache<NSNumber, UIImage>()

        override init() {
            super.init()
            cache.totalCostLimit = 24 * 1024 * 1024
        }

        func update(_ asset: GIFAsset, playing: Bool) {
            if self.asset !== asset {
                stop()
                self.asset = asset
                elapsed = 0
                displayedIndex = -1
                view?.image = asset.poster
                queue.async { [cache] in cache.removeAllObjects() }
            }
            if playing, link == nil {
                let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 60, preferred: 60)
                link.add(to: .main, forMode: .common)
                self.link = link
            } else if !playing { stop() }
        }

        func stop() {
            link?.invalidate()
            link = nil
            previousTimestamp = nil
        }

        @objc private func tick(_ link: CADisplayLink) {
            if let previousTimestamp { elapsed += link.timestamp - previousTimestamp }
            previousTimestamp = link.timestamp
            guard let asset else { return }
            let index = asset.frameIndex(at: elapsed)
            guard index != displayedIndex, !decoding else { return }
            decoding = true
            queue.async { [weak self, cache] in
                let image: UIImage? = autoreleasepool {
                    let key = NSNumber(value: index)
                    if let cached = cache.object(forKey: key) { return cached }
                    guard let image = asset.frame(at: index) else { return nil }
                    let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
                    cache.setObject(image, forKey: key, cost: cost)
                    return image
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.decoding = false
                    guard self.asset === asset, self.link != nil else { return }
                    if let image {
                        self.view?.image = image
                        self.displayedIndex = index
                    } else {
                        self.stop()
                        self.onFailure?()
                    }
                }
            }
        }
    }
}

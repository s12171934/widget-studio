import ImageIO
import UIKit
import UniformTypeIdentifiers

/// 원본 GIF와 프레임 정보. 위젯은 원본 대신 앱이 변환한 작은 PNG 장면들을 읽는다.
final class GIFAsset {
    static let maximumBytes = 12 * 1024 * 1024
    static let maximumFrames = 300
    let data: Data
    let delays: [TimeInterval]
    let duration: TimeInterval
    let poster: UIImage
    private let source: CGImageSource

    enum ImportError: LocalizedError {
        case tooLarge, notGIF, tooManyFrames, invalid, storage
        var errorDescription: String? {
            switch self {
            case .tooLarge: return "GIF는 12MB 이하로 골라 주세요."
            case .notGIF: return "GIF 파일을 골라 주세요. 사진이나 동영상은 GIF로 가져올 수 없습니다."
            case .tooManyFrames: return "300프레임 이하의 짧은 GIF를 골라 주세요."
            case .invalid: return "이 GIF를 읽을 수 없습니다. 다른 파일을 골라 주세요."
            case .storage: return "GIF를 저장할 수 없습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요."
            }
        }
    }

    init(data: Data) throws {
        guard data.count <= Self.maximumBytes else { throw ImportError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ImportError.invalid
        }
        guard CGImageSourceGetType(source) as String? == UTType.gif.identifier else { throw ImportError.notGIF }
        let count = CGImageSourceGetCount(source)
        guard count > 0, CGImageSourceGetStatus(source) == .statusComplete else { throw ImportError.invalid }
        guard count <= Self.maximumFrames else { throw ImportError.tooManyFrames }
        var delays: [TimeInterval] = []
        for index in 0..<count {
            guard CGImageSourceGetStatusAtIndex(source, index) == .statusComplete,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 8192, height <= 8192,
                  width * height <= 16_777_216 else { throw ImportError.invalid }
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            // 브라우저와 같이 지나치게 짧거나 잘못된 프레임 지연은 0.1초로 처리한다.
            delays.append(delay.isFinite && delay >= 0.02 ? min(delay, 10) : 0.1)
        }
        guard let poster = Self.frame(source: source, index: 0, maxSide: 900) else { throw ImportError.invalid }
        self.source = source
        self.data = data
        self.delays = delays
        self.duration = delays.reduce(0, +)
        self.poster = poster
    }

    static func readFile(_ url: URL) throws -> GIFAsset {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw ImportError.tooLarge }
        return try GIFAsset(data: Data(contentsOf: url))
    }

    func frameIndex(at elapsed: TimeInterval) -> Int {
        var remaining = max(0, elapsed).truncatingRemainder(dividingBy: duration)
        for (index, delay) in delays.enumerated() {
            if remaining < delay { return index }
            remaining -= delay
        }
        return delays.count - 1
    }

    /// 재생기의 직렬 큐에서만 호출한다. 모든 프레임을 한 번에 펼치지 않는다.
    func frame(at index: Int) -> UIImage? {
        guard delays.indices.contains(index) else { return nil }
        return Self.frame(source: source, index: index, maxSide: 600)
    }

    func widgetFrame(at elapsed: TimeInterval) -> UIImage? {
        Self.frame(source: source, index: frameIndex(at: elapsed), maxSide: GIFWidgetFrames.maximumSide)
    }

    private static func frame(source: CGImageSource, index: Int, maxSide: Int) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary).map { UIImage(cgImage: $0) }
    }
}

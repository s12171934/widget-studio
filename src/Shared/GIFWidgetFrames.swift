import Foundation
import ImageIO
import UIKit

/// 홈 위젯에는 원본을 디코딩하지 않고, 시간 간격에 맞춰 뽑은 작은 PNG 16장만 전달한다.
struct GIFWidgetFrames: Codable {
    static let count = 16
    static let maximumSide = 220
    let pngs: [Data]

    init(asset: GIFAsset) throws {
        pngs = try (0..<Self.count).map { index in
            guard let image = asset.widgetFrame(at: asset.duration * Double(index) / Double(Self.count)),
                  let data = image.pngData() else { throw GIFAsset.ImportError.invalid }
            return data
        }
    }

    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }

    static func images(from data: Data) -> [UIImage]? {
        guard data.count <= 4 * 1024 * 1024,
              let stored = try? PropertyListDecoder().decode(Self.self, from: data),
              stored.pngs.count == count else { return nil }
        var images: [UIImage] = []
        for png in stored.pngs {
            guard let source = CGImageSourceCreateWithData(png as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= maximumSide, height <= maximumSide,
                  let image = UIImage(data: png) else { return nil }
            images.append(image)
        }
        return images
    }
}

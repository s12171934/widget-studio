import Foundation
import UIKit

/// App Group 컨테이너에 디자인 목록(JSON)과 배경 사진을 저장한다.
/// 앱과 위젯 확장이 같은 저장소를 본다.
enum DesignStore {
    static let appGroupID = "group.io.github.s12171934.widgetstudio"
    private static let designsKey = "designs.v1"
    private static let seededKey = "seeded.v1"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func load() -> [WidgetDesign] {
        guard let data = defaults.data(forKey: designsKey),
              let designs = try? JSONDecoder().decode([WidgetDesign].self, from: data) else {
            return []
        }
        return designs
    }

    static func save(_ designs: [WidgetDesign]) {
        guard let data = try? JSONEncoder().encode(designs) else { return }
        defaults.set(data, forKey: designsKey)
    }

    static func design(id: UUID) -> WidgetDesign? {
        load().first { $0.id == id }
    }

    /// 처음 실행할 때 예시 디자인을 넣는다. 이미 넣었으면 아무것도 하지 않는다.
    static func seedIfNeeded() {
        guard !defaults.bool(forKey: seededKey) else { return }
        if load().isEmpty { save(WidgetDesign.samples) }
        defaults.set(true, forKey: seededKey)
    }

    // MARK: - 사진

    private static var photosDir: URL {
        let dir = containerURL.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func photoURL(for id: UUID) -> URL {
        photosDir.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// 위젯 메모리 한도를 넘지 않도록 긴 변 1000px 로 줄여 저장한다.
    static func savePhoto(_ image: UIImage, for id: UUID) {
        let resized = image.resized(maxSide: 1000)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: photoURL(for: id), options: .atomic)
    }

    static func loadPhoto(for id: UUID) -> UIImage? {
        UIImage(contentsOfFile: photoURL(for: id).path)
    }

    static func deletePhoto(for id: UUID) {
        try? FileManager.default.removeItem(at: photoURL(for: id))
    }
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

import Foundation
import Security
import UIKit

/// 앱과 위젯 확장이 함께 보는 저장소. 디자인 목록(JSON)과 배경 사진을 담는다.
///
/// 1순위는 키체인 공유 그룹이다 — 무료 Apple ID(Personal Team)는 App Group 을 쓸 수 없지만
/// 키체인 공유는 쓸 수 있어서, 실기기에서는 여기에 저장한다.
/// 키체인을 쓸 수 없는 환경(팀 없이 서명한 시뮬레이터 빌드)에서는 App Group 으로 내려간다.
enum DesignStore {
    static let appGroupID = "group.io.github.s12171934.widgetstudio"
    private static let designsKey = "designs.v1"
    private static let seededKey = "seeded.v1"

    // MARK: - 원시 저장 (키체인 → App Group)

    private static func read(_ key: String) -> Data? {
        if let data = SharedKeychain.read(key) { return data }
        return fallbackDefaults?.data(forKey: key)
    }

    @discardableResult
    private static func write(_ data: Data, _ key: String) -> Bool {
        if SharedKeychain.write(data, key) { return true }
        guard let d = fallbackDefaults else { return false }
        d.set(data, forKey: key)
        return true
    }

    private static func remove(_ key: String) {
        SharedKeychain.delete(key)
        fallbackDefaults?.removeObject(forKey: key)
    }

    private static var fallbackDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - 디자인

    static func load() -> [WidgetDesign] {
        guard let data = read(designsKey),
              let designs = try? JSONDecoder().decode([WidgetDesign].self, from: data) else {
            return []
        }
        return designs
    }

    static func save(_ designs: [WidgetDesign]) {
        guard let data = try? JSONEncoder().encode(designs) else { return }
        write(data, designsKey)
    }

    static func design(id: UUID) -> WidgetDesign? {
        load().first { $0.id == id }
    }

    /// 처음 실행할 때 예시 디자인을 넣는다. 이미 넣었으면 아무것도 하지 않는다.
    static func seedIfNeeded() {
        guard read(seededKey) == nil else { return }
        if load().isEmpty { save(WidgetDesign.samples) }
        write(Data([1]), seededKey)
    }

    // MARK: - 사진

    private static func photoKey(_ id: UUID) -> String { "photo.\(id.uuidString)" }

    /// 위젯 메모리 한도와 키체인 항목 크기를 고려해 긴 변 900px·JPEG 0.75 로 줄여 저장한다.
    static func savePhoto(_ image: UIImage, for id: UUID) {
        let resized = image.resized(maxSide: 900)
        guard let data = resized.jpegData(compressionQuality: 0.75) else { return }
        write(data, photoKey(id))
    }

    static func loadPhoto(for id: UUID) -> UIImage? {
        read(photoKey(id)).flatMap(UIImage.init(data:))
    }

    static func deletePhoto(for id: UUID) {
        remove(photoKey(id))
    }

    /// 예전 판의 「스크린샷 잘라내기 유리」 데이터(스크린샷·잘라 낸 배경·위젯 크기)를 지운다. 한 번만 돈다.
    static func removeLegacyGlassData() {
        guard read("legacyGlassRemoved.v1") == nil else { return }
        remove("wallpaper.v1")
        for family in ["small", "medium", "large"] {
            remove("size.\(family)")
            for design in load() { remove("glass.\(design.id.uuidString).\(family)") }
        }
        write(Data([1]), "legacyGlassRemoved.v1")
    }
}

/// 키체인 공유 그룹(`keychain-access-groups`)에 데이터를 둔다.
/// 그룹 이름은 빌드 때 Info.plist 의 `WSKeychainGroup` 에 팀 접두어까지 채워진다.
enum SharedKeychain {
    private static let service = "io.github.s12171934.widgetstudio"

    static var accessGroup: String? {
        guard let g = Bundle.main.object(forInfoDictionaryKey: "WSKeychainGroup") as? String,
              !g.isEmpty, !g.hasPrefix(".") else { return nil }
        return g
    }

    private static func baseQuery(_ key: String) -> [String: Any]? {
        guard let group = accessGroup else { return nil }
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: group,
        ]
    }

    static func read(_ key: String) -> Data? {
        guard var q = baseQuery(key) else { return nil }
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func write(_ data: Data, _ key: String) -> Bool {
        guard let q = baseQuery(key) else { return false }
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            // 위젯은 잠금 상태에서도 그려지므로, 부팅 뒤 한 번 잠금 해제 이후면 읽을 수 있게 한다.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemUpdate(q as CFDictionary, attrs as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        let add = q.merging(attrs) { $1 }
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ key: String) {
        guard let q = baseQuery(key) else { return }
        SecItemDelete(q as CFDictionary)
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

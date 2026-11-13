import AppIntents
import Foundation
import WidgetKit

struct WidgetActionIntent: AppIntent {
    static var title: LocalizedStringResource = "위젯 조작"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    @Parameter(title: "디자인") var designID: String
    @Parameter(title: "동작") var action: String
    @Parameter(title: "항목") var itemID: String?

    init() {}

    init(designID: UUID, action: WidgetAction, itemID: UUID? = nil) {
        self.designID = designID.uuidString
        self.action = action.rawValue
        self.itemID = itemID?.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: designID), let action = WidgetAction(rawValue: action) else {
            return .result()
        }
        try DesignStore.perform(action, for: id, itemID: itemID.flatMap(UUID.init(uuidString:)))
        WidgetCenter.shared.reloadTimelines(ofKind: "WidgetStudioWidget")
        return .result()
    }
}

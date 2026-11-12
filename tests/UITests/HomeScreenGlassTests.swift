import XCTest

/// 홈 화면에 위젯 스튜디오 위젯을 올리고, 유리(투명) 배경이 그 자리의 화면과 겹치는지 잰다.
/// 결과(전후 스크린샷·위젯 자리)는 환경변수 OUT_DIR(`TEST_RUNNER_OUT_DIR`)에 남기고, 비교는 밖에서 한다.
final class HomeScreenGlassTests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    private var outDir: URL!

    override func setUp() {
        continueAfterFailure = false
        let dir = ProcessInfo.processInfo.environment["OUT_DIR"] ?? NSTemporaryDirectory()
        outDir = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testGlassWidgetMatchesHomeScreen() throws {
        // 앱을 한 번 띄워 예시 디자인을 넣어 둔다.
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.press(.home)
        sleep(2)

        // 1. 위젯을 올리기 전 화면
        save(XCUIScreen.main.screenshot(), "before.png")

        // 2. 위젯 추가: 빈 곳 길게 → 편집 → 위젯 추가 → 검색 → 작게 추가
        let empty = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
        empty.press(forDuration: 1.6)
        sleep(1)
        try tap(firstOf: [springboard.buttons["편집"], springboard.buttons["Edit"]], step: "edit")
        sleep(1)
        try tap(firstOf: [springboard.buttons["위젯 추가"], springboard.buttons["Add Widget"]], step: "add-widget")
        sleep(2)

        // 막 설치한 직후에는 갤러리 색인이 늦어 검색 결과가 비기도 한다 — 몇 번 다시 찾는다.
        let search = springboard.searchFields.firstMatch
        if search.waitForExistence(timeout: 3) {
            for attempt in 0..<6 {
                search.tap()
                if attempt > 0, springboard.buttons["텍스트 지우기"].exists {
                    springboard.buttons["텍스트 지우기"].tap()
                }
                search.typeText("위젯 스튜디오")
                sleep(2)
                let none = springboard.staticTexts.matching(NSPredicate(format: "label CONTAINS '결과 없음'")).firstMatch
                if !none.exists { break }
                sleep(5)
            }
        }
        try tap(firstOf: [springboard.cells.containing(.staticText, identifier: "위젯 스튜디오").firstMatch,
                          springboard.buttons["위젯 스튜디오"],
                          springboard.staticTexts["위젯 스튜디오"]], step: "pick-app")
        sleep(2)
        // 확인 버튼 레이블은 앞에 기호 자리 공백이 붙는다(' 위젯 추가').
        try tap(firstOf: [springboard.buttons.matching(NSPredicate(format: "label CONTAINS '위젯 추가'")).firstMatch,
                          springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget'")).firstMatch],
                step: "confirm-add")
        sleep(2)
        try tap(firstOf: [springboard.buttons["완료"], springboard.buttons["Done"]], step: "done")
        sleep(3)

        // 3. 위젯 자리
        // 앱 아이콘과 위젯이 같은 이름을 가진다 — 화면 안에서 가장 큰 것이 위젯이다.
        try? springboard.debugDescription.write(to: outDir.appendingPathComponent("tree-added.txt"),
                                                atomically: true, encoding: .utf8)
        // 같은 이름의 아이콘(Icon)은 이름표까지 포함해 더 크다. 위젯 내용은 Other 요소다.
        let widget = springboard.otherElements.matching(NSPredicate(format: "label == '위젯 스튜디오'")).firstMatch
        guard widget.waitForExistence(timeout: 5) else {
            dump("widget-frame")
            throw NSError(domain: "HomeScreenGlassTests", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "홈 화면에서 위젯을 찾지 못함"])
        }
        let screen = springboard.frame.size
        let f = widget.frame
        let rect = [f.minX / screen.width, f.minY / screen.height, f.width / screen.width, f.height / screen.height]
        let rectString = rect.map { String(format: "%.6f", $0) }.joined(separator: ",")
        try rectString.write(to: outDir.appendingPathComponent("rect.txt"), atomically: true, encoding: .utf8)
        save(XCUIScreen.main.screenshot(), "added.png")

        // 4. 앱에 전 화면과 자리를 넘겨 유리 배경을 만든다.
        app.launchArguments = ["-glassTestShot", outDir.appendingPathComponent("before.png").path,
                               "-glassTestRect", rectString]
        app.launch()
        sleep(3)
        XCUIDevice.shared.press(.home)
        sleep(4)

        // 5. 결과 화면
        save(XCUIScreen.main.screenshot(), "after.png")
    }

    // MARK: - 도우미

    private func save(_ shot: XCUIScreenshot, _ name: String) {
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent(name))
    }

    private func dump(_ step: String) {
        try? springboard.debugDescription.write(to: outDir.appendingPathComponent("tree-\(step).txt"),
                                                atomically: true, encoding: .utf8)
        save(XCUIScreen.main.screenshot(), "fail-\(step).png")
    }

    private func find(firstOf candidates: [XCUIElement], step: String) throws -> XCUIElement {
        for _ in 0..<6 {
            if let hit = candidates.first(where: { $0.exists }) { return hit }
            sleep(1)
        }
        dump(step)
        throw NSError(domain: "HomeScreenGlassTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "단계 \(step): 요소를 찾지 못함 (tree-\(step).txt 참고)"])
    }

    private func tap(firstOf candidates: [XCUIElement], step: String) throws {
        try find(firstOf: candidates, step: step).tap()
    }
}

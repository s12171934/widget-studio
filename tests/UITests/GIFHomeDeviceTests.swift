import XCTest

/// 실기기에 GIF 디자인과 홈 위젯이 저장된 상태에서 실행한다. 사용자 사진 보관함은 조작하지 않는다.
final class GIFHomeDeviceTests: XCTestCase {
    func testSavedGIFAnimatesWithoutAppInForeground() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("시뮬레이터는 GIFUITests의 가져오기·홈 재생 시나리오로 검증한다")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        Thread.sleep(forTimeInterval: 3)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        home.activate()
        XCUIDevice.shared.press(.home)
        for _ in 0..<3 { home.swipeRight() }
        let widget = home.icons.matching(NSPredicate(format: "label == '위젯 스튜디오' AND value == '위젯'")).firstMatch
        for _ in 0..<4 {
            if widget.exists && widget.isHittable { break }
            home.swipeLeft()
        }
        XCTAssertTrue(widget.waitForExistence(timeout: 10), "GIF 디자인이 선택된 홈 위젯이 필요하다")
        Thread.sleep(forTimeInterval: 2)
        var frames = Set<Data>()
        for index in 0..<12 {
            XCTAssertNotEqual(app.state, .runningForeground)
            let screenshot = widget.screenshot()
            frames.insert(screenshot.pngRepresentation)
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "gif-home-device-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertGreaterThan(frames.count, 1, "앱을 열지 않아도 홈 화면에서 GIF 장면이 바뀌어야 한다")
        #endif
    }
}

import XCTest
import UIKit

final class WidgetFeatureUITests: XCTestCase {
    private let app = XCUIApplication()
    private var editor: XCUIElement { app.collectionViews.firstMatch }
    private var remaining: XCUIElement { editor.descendants(matching: .any)["pomodoro-remaining"].firstMatch }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.press(.home)
        app.launch()
    }

    func testFeatureCreationPreviewButtonsAndExtraLarge() throws {
        app.buttons["새 디자인"].tap()
        screenshot("template-picker")
        for template in ["checklist", "counter", "focus", "calendar", "gif"] {
            let button = app.buttons["create-\(template)"]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                           "추가 메뉴가 화면 안에 있어야 한다: \(template)\n\(app.debugDescription)")
        }
        app.buttons["create-counter"].tap()
        let increment = editor.buttons["widget-increment"]
        XCTAssertTrue(increment.waitForExistence(timeout: 5))
        increment.tap()
        XCTAssertTrue(editor.staticTexts["1"].firstMatch.waitForExistence(timeout: 5))
        editor.buttons["widget-decrement"].tap()
        editor.buttons["widget-resetCounter"].tap()
        app.buttons["X-large"].tap()
        XCTAssertTrue(app.staticTexts["X-large는 iPad 홈 화면에서 사용할 수 있습니다. iPhone은 작게·중간·크게를 지원합니다."].exists)
        screenshot("counter-extra-large-preview")
        app.buttons["save-design"].tap()

        for template in ["checklist", "focus", "calendar"] {
            app.buttons["새 디자인"].tap()
            app.buttons["create-\(template)"].tap()
            if template == "checklist" {
                let toggle = editor.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'widget-toggleItem-' ")).firstMatch
                XCTAssertTrue(toggle.waitForExistence(timeout: 5))
                toggle.tap()
                XCTAssertTrue(editor.staticTexts["1/3"].waitForExistence(timeout: 5))
            } else if template == "focus" {
                editor.buttons["widget-toggleTimer"].tap()
                XCTAssertTrue(editor.buttons["정지"].waitForExistence(timeout: 5))
                editor.buttons["widget-toggleTimer"].tap()
                editor.buttons["widget-resetTimer"].tap()
            }
            app.buttons["X-large"].tap()
            screenshot("\(template)-extra-large-preview")
            app.buttons["save-design"].tap()
        }
    }

    func testHomeCounterButtonsAndSizeGallery() throws {
        app.buttons["새 디자인"].tap()
        app.buttons["create-counter"].tap()
        app.buttons["save-design"].tap()
        let home = try installHomeWidget(designName: "새 카운터")
        let increment = home.buttons["카운터 증가"].firstMatch
        XCTAssertTrue(increment.waitForExistence(timeout: 10), home.debugDescription)
        increment.tap()
        XCTAssertNotEqual(app.state, .runningForeground, "위젯 조작으로 앱을 열면 안 된다")
        XCTAssertTrue(home.staticTexts["1"].firstMatch.waitForExistence(timeout: 5), home.debugDescription)
        screenshot("home-counter-incremented")
        home.buttons["카운터 초기화"].firstMatch.tap()
        screenshot("home-counter-reset")
    }

    func testPomodoroCreationAndHomeControls() throws {
        app.buttons["새 디자인"].tap()
        let create = app.buttons["create-pomodoro"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()
        screenshot("pomodoro-initial")
        XCTAssertFalse(remaining.exists, "빨간 시계는 남은 5분부터 숫자를 표시한다")
        let dial = editor.descendants(matching: .any)["pomodoro-dial"].firstMatch
        XCTAssertTrue(dial.waitForExistence(timeout: 5))
        screenshot("pomodoro-red-dial-large")
        editor.buttons["숫자형"].tap()
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: dial)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)
        XCTAssertTrue(remaining.waitForExistence(timeout: 5))
        XCTAssertEqual(remaining.label, "25:00")
        screenshot("pomodoro-digital-option")
        editor.buttons["빨간 시계"].tap()
        XCTAssertTrue(dial.waitForExistence(timeout: 5))
        editor.buttons["widget-toggleTimer"].tap()
        XCTAssertTrue(editor.buttons["정지"].waitForExistence(timeout: 5))
        editor.buttons["widget-toggleTimer"].tap()
        XCTAssertTrue(editor.buttons["재개"].waitForExistence(timeout: 5))
        editor.buttons["widget-resetTimer"].tap()
        XCTAssertFalse(remaining.exists)
        app.buttons["X-large"].tap()
        screenshot("pomodoro-extra-large-preview")
        app.buttons["save-design"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["새 포모도로"].firstMatch.waitForExistence(timeout: 5))
        let home = try installHomeWidget(designName: "새 포모도로", large: true)
        let start = home.buttons["시작"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 10), home.debugDescription)
        screenshot("pomodoro-home-ready")
        start.tap()
        let pause = home.buttons["정지"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 10), home.debugDescription)
        XCTAssertNotEqual(app.state, .runningForeground)
        let widget = try XCTUnwrap(home.icons.matching(identifier: "위젯 스튜디오").allElementsBoundByIndex.first {
            $0.frame.width > 100 && $0.frame.height > 100 && home.frame.contains($0.frame)
        })
        Thread.sleep(forTimeInterval: 2)
        let initialRed = redPixels(onScreen: widget.frame, screen: home.frame)
        screenshot("pomodoro-home-running")
        XCTAssertGreaterThan(initialRed, 100, "실행 중에도 빨간 부채꼴이 보여야 한다")
        Thread.sleep(forTimeInterval: 8)
        let laterRed = redPixels(onScreen: widget.frame, screen: home.frame)
        XCTAssertLessThan(laterRed, initialRed, "앱을 열지 않고 빨간 영역이 줄어야 한다: \(initialRed) → \(laterRed)")
        if let directory = ProcessInfo.processInfo.environment["OUT_DIR"] {
            try? "\(initialRed) → \(laterRed)".write(to: URL(fileURLWithPath: directory).appendingPathComponent("red-sector-counts.txt"), atomically: true, encoding: .utf8)
        }
        screenshot("pomodoro-home-red-decreased")
        pause.tap()
        XCTAssertTrue(home.buttons["재개"].firstMatch.waitForExistence(timeout: 10))
        screenshot("pomodoro-home-paused")
        home.buttons["재개"].firstMatch.tap()
        XCTAssertTrue(home.buttons["정지"].firstMatch.waitForExistence(timeout: 10))
        home.buttons["포모도로 초기화"].firstMatch.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
    }

    private func installHomeWidget(designName: String, large: Bool = false) throws -> XCUIApplication {
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCUIDevice.shared.press(.home)
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68)).press(forDuration: 1.6)
        let edit = home.buttons["편집"].exists ? home.buttons["편집"] : home.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), home.debugDescription)
        edit.tap()
        let add = home.buttons["위젯 추가"].exists ? home.buttons["위젯 추가"] : home.buttons["Add Widget"]
        add.tap()
        let search = home.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("위젯 스튜디오")
        let result = home.staticTexts["위젯 스튜디오"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.tap()
        let extraLarge = ProcessInfo.processInfo.environment["EXPECT_EXTRA_LARGE"] == "1"
        if extraLarge || large {
            for _ in 0..<(extraLarge ? 3 : 2) {
                home.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.55))
                    .press(forDuration: 0.05, thenDragTo: home.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.55)))
            }
        }
        screenshot("widget-size-gallery")
        let confirm = home.buttons.matching(NSPredicate(format: "label CONTAINS '위젯 추가' OR label CONTAINS 'Add Widget'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let done = home.buttons["완료"].exists ? home.buttons["완료"] : home.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        let widget = try XCTUnwrap(home.icons.matching(identifier: "위젯 스튜디오").allElementsBoundByIndex.first {
            $0.frame.width > 100 && $0.frame.height > 100 && home.frame.contains($0.frame)
        }, home.debugDescription)
        if extraLarge {
            XCTAssertGreaterThan(widget.frame.width / widget.frame.height, 1.6, "iPad에 실제 X-large 크기로 놓여야 한다")
        }
        widget.press(forDuration: 1.2)
        let editWidget = home.buttons.matching(NSPredicate(format: "label CONTAINS '위젯 편집' OR label CONTAINS 'Edit Widget'")).firstMatch
        XCTAssertTrue(editWidget.waitForExistence(timeout: 5), home.debugDescription)
        editWidget.tap()
        let selection = home.tables.firstMatch.buttons.firstMatch
        XCTAssertTrue(selection.waitForExistence(timeout: 5), home.debugDescription)
        selection.tap()
        let design = home.buttons[designName].firstMatch
        XCTAssertTrue(design.waitForExistence(timeout: 5), home.debugDescription)
        design.tap()
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        return home
    }

    private func screenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.5) // 크기 선택기의 전환이 끝난 화면을 기록한다.
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["OUT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
        }
    }

    private func redPixels(onScreen frame: CGRect, screen: CGRect) -> Int {
        guard let screenImage = XCUIScreen.main.screenshot().image.cgImage else { return 0 }
        let scale = CGFloat(screenImage.width) / screen.width
        guard let image = screenImage.cropping(to: frame.applying(CGAffineTransform(scaleX: scale, y: scale))) else { return 0 }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return 0 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: pixels.count, by: 4).reduce(0) { count, index in
            let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
            return count + (r > 170 && g < 110 && b < 120 && r > 2 * g ? 1 : 0)
        }
    }
}

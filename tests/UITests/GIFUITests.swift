import XCTest

final class GIFUITests: XCTestCase {
    private let app = XCUIApplication()

    func testPresetSelectionPlaybackSearchAndFileImportHandoff() throws {
        continueAfterFailure = false
        XCUIDevice.shared.press(.home)
        app.launch()
        app.buttons["새 디자인"].tap()
        app.buttons["create-gif"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists, "새 GIF에는 파일 읽기 오류가 없어야 한다")
        let presets = app.buttons["pick-gif-preset"]
        reveal(presets)
        presets.tap()
        XCTAssertTrue(app.navigationBars["GIF 라이브러리"].waitForExistence(timeout: 5))
        saveScreenshot("gif-presets.png")
        app.buttons["preset-stars"].tap()
        XCTAssertTrue(app.navigationBars["별빛 여행"].waitForExistence(timeout: 15))
        let preview = app.buttons["preview-gif"]
        reveal(preview)
        preview.tap()
        XCTAssertTrue(app.buttons["일시 정지"].waitForExistence(timeout: 5))
        saveScreenshot("gif-preset-playing.png")
        app.buttons["닫기"].tap()

        let search = app.buttons["find-gif-online"]
        reveal(search)
        search.tap()
        let query = app.textFields["gif-search-query"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.tap()
        query.typeText("cat dog\n")
        let keyboardDismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [keyboardDismissed], timeout: 5), .completed)
        for provider in ["pixabay", "giphy", "tenor"] {
            XCTAssertTrue(app.descendants(matching: .any)["gif-search-\(provider)"].firstMatch.exists)
        }
        saveScreenshot("gif-search-links.png")
        let download = app.buttons["import-downloaded-gif"]
        reveal(download)
        download.tap()
        let files = app.otherElements["Browse View (Picker)"]
        let filePickerPresented = files.waitForExistence(timeout: 10)
        saveScreenshot("gif-download-import.png")
        XCTAssertTrue(filePickerPresented, app.debugDescription)
        let fileNavigation = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        let cancel = fileNavigation.buttons.matching(NSPredicate(format: "label == '취소' OR label == 'Cancel'")).firstMatch
        XCTAssertTrue(cancel.exists)
        // 원격 문서 UI는 isHittable이 false여도 표시된다. 확인된 버튼 프레임으로 누른다.
        cancel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["GIF 라이브러리"].waitForExistence(timeout: 5))
        app.buttons["닫기"].tap()
        XCTAssertTrue(app.buttons["save-design"].isEnabled)
        app.buttons["save-design"].tap()
        XCTAssertTrue(app.staticTexts["별빛 여행"].firstMatch.waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<4 {
            if element.exists && element.isHittable { return }
            app.collectionViews.firstMatch.swipeUp()
        }
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            app.collectionViews.firstMatch.swipeDown()
        }
    }

    func testGIFImportPlaybackAndSave() throws {
        continueAfterFailure = false
        XCUIDevice.shared.press(.home)
        app.launch()
        app.buttons["새 디자인"].tap()
        app.buttons["create-gif"].tap()
        let picker = app.buttons["pick-gif-photos"]
        if !picker.isHittable { app.swipeUp() }
        picker.tap()
        // 테스트 전에 simctl addmedia로 GIF 한 개를 보관함에 넣는다.
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), app.debugDescription)
        photo.tap()
        let preview = app.buttons["preview-gif"]
        for _ in 0..<4 {
            if preview.exists && preview.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(preview.waitForExistence(timeout: 15), app.debugDescription)
        if !preview.isHittable { app.swipeUp() }
        preview.tap()
        let player = app.descendants(matching: .any)["gif-player"].firstMatch
        XCTAssertTrue(player.waitForExistence(timeout: 10))
        let first = player.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 0.35)
        XCTAssertNotEqual(first, player.screenshot().pngRepresentation, "GIF의 장면이 실제로 바뀌어야 한다")
        app.buttons["일시 정지"].tap()
        Thread.sleep(forTimeInterval: 0.25)
        let paused = player.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 0.35)
        XCTAssertEqual(paused, player.screenshot().pngRepresentation, "일시 정지하면 장면을 유지해야 한다")
        app.buttons["재생"].tap()
        saveScreenshot("gif-player.png")
        app.buttons["닫기"].tap()
        app.buttons["save-design"].tap()
        XCTAssertTrue(app.staticTexts["새 GIF"].waitForExistence(timeout: 5))
        saveScreenshot("gif-library.png")
        try verifyHomeScreenWidget()
    }

    private func verifyHomeScreenWidget() throws {
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCUIDevice.shared.press(.home)
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68)).press(forDuration: 1.6)
        let edit = home.buttons["편집"].exists ? home.buttons["편집"] : home.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
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
        let confirm = home.buttons.matching(NSPredicate(format: "label CONTAINS '위젯 추가' OR label CONTAINS 'Add Widget'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let done = home.buttons["완료"].exists ? home.buttons["완료"] : home.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        Thread.sleep(forTimeInterval: 2)
        let widget = home.otherElements.matching(NSPredicate(format: "label == '위젯 스튜디오'")).firstMatch
        XCTAssertTrue(widget.waitForExistence(timeout: 5))
        widget.press(forDuration: 1.2)
        let editWidget = home.buttons.matching(NSPredicate(format: "label CONTAINS '위젯 편집' OR label CONTAINS 'Edit Widget'")).firstMatch
        XCTAssertTrue(editWidget.waitForExistence(timeout: 5), home.debugDescription)
        editWidget.tap()
        // 구성 행의 레이블이 아니라 현재 선택값 버튼을 누른다.
        let value = home.tables.firstMatch.buttons.firstMatch
        XCTAssertTrue(value.waitForExistence(timeout: 10), home.debugDescription)
        value.tap()
        saveScreenshot("gif-design-picker.png")
        let gif = home.buttons["새 GIF"].firstMatch
        XCTAssertTrue(gif.waitForExistence(timeout: 5), home.debugDescription)
        gif.tap()
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()
        Thread.sleep(forTimeInterval: 2)
        saveScreenshot("gif-widget.png")
        let poster = widget.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 0.35)
        XCTAssertEqual(poster, widget.screenshot().pngRepresentation, "홈 화면에서는 GIF의 대표 장면을 유지해야 한다")
        widget.tap()
        XCTAssertTrue(app.buttons["일시 정지"].waitForExistence(timeout: 5), app.debugDescription)
        saveScreenshot("gif-widget-opened-player.png")
    }

    private func saveScreenshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["OUT_DIR"] {
            let root = URL(fileURLWithPath: directory)
            try? shot.pngRepresentation.write(to: root.appendingPathComponent(name))
            try? app.debugDescription.write(to: root.appendingPathComponent(name + ".tree.txt"), atomically: true, encoding: .utf8)
        }
    }
}

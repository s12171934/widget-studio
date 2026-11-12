import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import WidgetStudio

final class GIFAssetTests: XCTestCase {
    private func fixture(colors: [UIColor] = [.red, .blue], delays: [Double] = [0.25, 0.5],
                         size: CGSize = CGSize(width: 20, height: 20)) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, colors.count, nil))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        for (index, color) in colors.enumerated() {
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                color.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delays[index % delays.count]],
            ] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    func testVariableFrameDelaysAndLoop() throws {
        let data = try fixture()
        let asset = try GIFAsset(data: data)
        XCTAssertEqual(asset.delays.count, 2)
        XCTAssertEqual(asset.duration, 0.75, accuracy: 0.01)
        XCTAssertEqual(asset.frameIndex(at: 0.24), 0)
        XCTAssertEqual(asset.frameIndex(at: 0.26), 1)
        XCTAssertEqual(asset.frameIndex(at: 0.76), 0)
        XCTAssertEqual(asset.data, data)
    }

    func testPosterAndPlaybackFramesHaveDifferentPixels() throws {
        let asset = try GIFAsset(data: fixture())
        let first = try XCTUnwrap(asset.poster.pngData())
        let second = try XCTUnwrap(asset.frame(at: 1)?.pngData())
        XCTAssertNotEqual(first, second)
        XCTAssertNil(asset.frame(at: -1))
        XCTAssertNil(asset.frame(at: 2))
    }

    func testRejectsNonGIFAndTruncatedGIF() throws {
        let png = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }.pngData()!
        XCTAssertThrowsError(try GIFAsset(data: png))
        let gif = try fixture()
        XCTAssertThrowsError(try GIFAsset(data: gif.prefix(gif.count / 2)))
    }

    func testRejectsFileSizeAndFrameCountBeyondBudgets() throws {
        XCTAssertThrowsError(try GIFAsset(data: Data(repeating: 0, count: GIFAsset.maximumBytes + 1)))
        let many = try fixture(colors: Array(repeating: .red, count: 301), size: CGSize(width: 1, height: 1))
        XCTAssertThrowsError(try GIFAsset(data: many))
    }

    func testRejectsExtremePixelDimensions() throws {
        XCTAssertThrowsError(try GIFAsset(data: fixture(size: CGSize(width: 8193, height: 1))))
    }

    func testFileImportReadsOriginalAndRejectsOtherFormats() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".gif")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try fixture()
        try data.write(to: url)
        XCTAssertEqual(try GIFAsset.readFile(url).data, data)
        try Data("not a gif".utf8).write(to: url)
        XCTAssertThrowsError(try GIFAsset.readFile(url))
    }

    func testTransparentPosterRemainsTransparentInSharedStorage() throws {
        let id = UUID()
        defer {
            try? DesignStore.deleteGIF(for: id)
            DesignStore.deletePhoto(for: id)
        }
        let asset = try GIFAsset(data: fixture(colors: [.clear, .red]))
        try DesignStore.saveGIF(asset, for: id)
        let image = try XCTUnwrap(DesignStore.loadPhoto(for: id)?.cgImage)
        var pixel = [UInt8](repeating: 255, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertEqual(pixel[3], 0)
    }

    func testGIFOriginalAndPosterSurviveCopyAndIndependentDeletion() throws {
        let source = UUID(), copy = UUID()
        defer {
            try? DesignStore.deleteGIF(for: source)
            try? DesignStore.deleteGIF(for: copy)
            DesignStore.deletePhoto(for: source)
            DesignStore.deletePhoto(for: copy)
        }
        let asset = try GIFAsset(data: fixture())
        try DesignStore.saveGIF(asset, for: source)
        try DesignStore.copyGIF(from: source, to: copy)
        XCTAssertEqual(DesignStore.loadGIFData(for: copy), asset.data)
        XCTAssertNotNil(DesignStore.loadPhoto(for: copy))
        try DesignStore.deleteGIF(for: source)
        DesignStore.deletePhoto(for: source)
        XCTAssertNil(DesignStore.loadGIFData(for: source))
        XCTAssertNil(DesignStore.loadPhoto(for: source))
        XCTAssertEqual(DesignStore.loadGIFData(for: copy), asset.data)
        XCTAssertThrowsError(try DesignStore.copyGIF(from: UUID(), to: UUID()))
    }

    func testWidgetTapOpensGIFPlayerAndOtherDesignsStillOpenEditor() {
        let gif = WidgetDesign(name: "GIF", template: .gif, title: "")
        let photo = WidgetDesign(name: "사진", template: .photo, title: "")
        XCTAssertEqual(gif.widgetURL?.host, "play")
        XCTAssertEqual(gif.widgetURL?.lastPathComponent, gif.id.uuidString)
        XCTAssertEqual(photo.widgetURL?.host, "design")
    }

    func testAllBuiltInPresetsProduceValidMovingGIFsWithinImportBudgets() throws {
        for preset in GIFPreset.allCases {
            let asset = try preset.makeAsset()
            XCTAssertEqual(asset.delays.count, 36, preset.title)
            XCTAssertEqual(asset.duration, 2.88, accuracy: 0.01, preset.title)
            XCTAssertLessThan(asset.data.count, GIFAsset.maximumBytes, preset.title)
            XCTAssertNotEqual(asset.frame(at: 0)?.pngData(), asset.frame(at: 7)?.pngData(), preset.title)
            if let directory = ProcessInfo.processInfo.environment["OUT_DIR"] {
                let root = URL(fileURLWithPath: directory)
                try asset.poster.pngData()?.write(to: root.appendingPathComponent("preset-\(preset.id).png"))
                try asset.data.write(to: root.appendingPathComponent("preset-\(preset.id).gif"))
            }
        }
    }

    func testSearchLinksEncodeKeywordsAndKeepDestinationHost() throws {
        XCTAssertEqual(GIFSearchProvider.pixabay.searchURL(query: "cat dog").absoluteString,
                       "https://pixabay.com/gifs/search/cat%20dog/")
        XCTAssertEqual(GIFSearchProvider.giphy.searchURL(query: "cat dog").absoluteString,
                       "https://giphy.com/explore/cat-dog")
        XCTAssertEqual(GIFSearchProvider.tenor.searchURL(query: "cat dog").absoluteString,
                       "https://tenor.com/search/cat-dog-gifs")
        for provider in GIFSearchProvider.allCases {
            let url = provider.searchURL(query: "  고양이/하트?100%#  ")
            XCTAssertEqual(url.scheme, "https")
            XCTAssertTrue(url.absoluteString.contains("%2F"))
            XCTAssertNil(url.query)
            XCTAssertNil(url.fragment)
            XCTAssertEqual(provider.searchURL(query: " \n ").host, url.host)
        }
    }
}

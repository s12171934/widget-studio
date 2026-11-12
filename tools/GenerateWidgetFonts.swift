import Foundation

@main
struct GenerateWidgetFonts {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = root.appendingPathComponent(".build/WidgetFonts", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try WidgetAnimationFont.makeMask()
            .write(to: output.appendingPathComponent("WSGIFMask.ttf"), options: .atomic)
    }
}

import Foundation

@main
struct GenerateWidgetFonts {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = root.appendingPathComponent(".build/WidgetFonts", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try WidgetAnimationFont.makeMask()
            .write(to: output.appendingPathComponent("WSGIFMask.ttf"), options: .atomic)
        for file in try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
            where file.lastPathComponent.hasPrefix("WSPomodoro") {
            try FileManager.default.removeItem(at: file)
        }
        for minutes in [60] {
            for place in 0..<5 {
                for selector in [false, true] where !selector || place > 0 {
                    let data = PomodoroDialFont.make(minutes: minutes, place: place, selector: selector)
                    try PomodoroDialFont.validate(data)
                    let family = PomodoroDialFont.family(minutes: minutes, place: place, selector: selector)
                    try data.write(to: output.appendingPathComponent("\(family).ttf"), options: .atomic)
                }
            }
        }
    }
}

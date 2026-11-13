import Foundation
import CoreText

/// 타이머의 각 자리 숫자를 원형 구간으로 그리는 작은 글꼴이다.
/// WidgetKit의 자리별 숫자 갱신을 그대로 사용하며 합자 조형에 의존하지 않는다.
enum PomodoroDialFont {
    static let units = [1, 10, 60, 600, 3600]
    static let periods = [10, 60, 600, 3600, 36_000]
    private static let em = 2048

    static func family(minutes: Int, place: Int, selector: Bool) -> String {
        "WSPomodoro\(minutes)\(selector ? "Select" : "Fill")\(place)"
    }

    static func make(minutes: Int, place: Int, selector: Bool) -> Data {
        let family = family(minutes: minutes, place: place, selector: selector)
        var tables: [String: Data] = [:]
        var head = Bytes()
        head.u32(0x00010000); head.u32(0x00010000); head.u32(0); head.u32(0x5F0F3CF5)
        head.u16(3); head.u16(em); head.u32(0); head.u32(0); head.u32(0); head.u32(0)
        [0, 0, em, em, 0, 8, 2, 1, 0].forEach { head.u16($0) }
        tables["head"] = head.data
        var hhea = Bytes(); hhea.u32(0x00010000)
        [em, 0, 0, em, 0, 0, em, 1, 0, 0, 0, 0, 0, 0, 0, 13].forEach { hhea.u16($0) }
        tables["hhea"] = hhea.data
        var maxp = Bytes(); maxp.u32(0x00010000)
        [13, 5000, 1200, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0].forEach { maxp.u16($0) }
        tables["maxp"] = maxp.data
        var hmtx = Bytes(), glyf = Bytes(), loca = Bytes()
        for index in 0..<13 {
            hmtx.u16(em); hmtx.u16(0)
            loca.u32(glyf.data.count)
            if (2...11).contains(index) {
                patternGlyph(digit: index - 2, minutes: minutes, place: place, selector: selector, into: &glyf)
            } else { for _ in 0..<5 { glyf.u16(0) } }
            glyf.pad()
        }
        loca.u32(glyf.data.count)
        tables["hmtx"] = hmtx.data; tables["glyf"] = glyf.data; tables["loca"] = loca.data
        var mapping: [Int: Int] = [32: 1, 58: 12]
        for digit in 0..<10 { mapping[48 + digit] = digit + 2 }
        let codes = mapping.keys.sorted() + [65535], count = codes.count
        let power = 1 << Int(log2(Double(count)))
        var sub = Bytes()
        [4, 16 + count * 8, 0, count * 2, power * 2, Int(log2(Double(power))), count * 2 - power * 2].forEach { sub.u16($0) }
        codes.forEach { sub.u16($0) }; sub.u16(0); codes.forEach { sub.u16($0) }
        codes.forEach { sub.u16($0 == 65535 ? 1 : mapping[$0]! - $0) }
        codes.forEach { _ in sub.u16(0) }
        var cmap = Bytes(); cmap.u16(0); cmap.u16(1); cmap.u16(3); cmap.u16(1); cmap.u32(12); cmap.data.append(sub.data)
        tables["cmap"] = cmap.data
        let names = [(1, family), (2, "Regular"), (3, family + "-Regular"), (4, family + " Regular"), (6, family + "-Regular")]
        var name = Bytes(), strings = Bytes()
        name.u16(0); name.u16(names.count); name.u16(6 + names.count * 12)
        for (id, value) in names {
            let data = value.data(using: .utf16BigEndian)!
            [3, 1, 0x0409, id, data.count, strings.data.count].forEach { name.u16($0) }
            strings.data.append(data)
        }
        name.data.append(strings.data); tables["name"] = name.data
        var post = Bytes(); post.u32(0x00030000); post.data.append(Data(repeating: 0, count: 28)); tables["post"] = post.data
        var os2 = Bytes()
        [3, em, 400, 5, 0, 650, 600, 0, 75, 650, 600, 0, 350, 50, 250, 0].forEach { os2.u16($0) }
        os2.data.append(Data(repeating: 0, count: 10)); [1, 0, 0, 0].forEach { os2.u32($0) }
        os2.data.append(contentsOf: Array("WSTU".utf8))
        [64, 32, 58, em, 0, 0, em, 0].forEach { os2.u16($0) }
        os2.u32(1); os2.u32(0); [em, em, 0, 32, 1].forEach { os2.u16($0) }
        tables["OS/2"] = os2.data
        return package(tables)
    }

    static func validate(_ data: Data) throws {
        guard let provider = CGDataProvider(data: data as CFData), let graphics = CGFont(provider) else { throw FontError.invalid }
        let font = CTFontCreateWithGraphicsFont(graphics, 1000, nil, nil)
        var characters = Array("0123456789".utf16), glyphs = [CGGlyph](repeating: 0, count: 10)
        guard CTFontGetGlyphsForCharacters(font, &characters, &glyphs, 10), glyphs == (2...11).map({ CGGlyph($0) }) else {
            throw FontError.invalid
        }
    }

    private static func patternGlyph(digit: Int, minutes: Int, place: Int, selector: Bool, into bytes: inout Bytes) {
        let total = minutes * 60, unit = units[place], period = periods[place]
        var contours: [[(Int, Int)]] = []
        for base in stride(from: 0, to: total, by: period) {
            let start = selector ? base + digit * unit : base
            let end = min(total, base + min(period, (selector ? digit + 1 : digit) * unit))
            guard start < end else { continue }
            let steps = max(1, Int(ceil(Double(end - start) / Double(total) * 180)))
            var points = [(em / 2, em / 2)]
            for step in 0...steps {
                let value = Double(start) + Double(end - start) * Double(step) / Double(steps)
                let angle = Double.pi / 2 - value / Double(total) * 2 * .pi
                points.append((Int((Double(em) / 2 * (1 + cos(angle))).rounded()),
                               Int((Double(em) / 2 * (1 + sin(angle))).rounded())))
            }
            contours.append(points)
        }
        guard !contours.isEmpty else { for _ in 0..<5 { bytes.u16(0) }; return }
        bytes.u16(contours.count); [0, 0, em, em].forEach { bytes.u16($0) }
        var endpoint = -1
        for contour in contours { endpoint += contour.count; bytes.u16(endpoint) }
        bytes.u16(0)
        let points = contours.flatMap { $0 }
        for _ in points { bytes.data.append(1) }
        var previous = 0
        for point in points { bytes.u16(point.0 - previous); previous = point.0 }
        previous = 0
        for point in points { bytes.u16(point.1 - previous); previous = point.1 }
    }

    private static func package(_ tables: [String: Data]) -> Data {
        let tags = tables.keys.sorted(), count = tags.count, power = 1 << Int(log2(Double(count)))
        var result = Bytes(); result.u32(0x00010000)
        [count, power * 16, Int(log2(Double(power))), count * 16 - power * 16].forEach { result.u16($0) }
        var payload = Bytes(), adjustmentOffset = 0
        for tag in tags {
            let data = tables[tag]!, offset = 12 + count * 16 + payload.data.count
            result.tag(tag); result.u32(checksum(data)); result.u32(offset); result.u32(data.count)
            if tag == "head" { adjustmentOffset = offset + 8 }
            payload.data.append(data); payload.pad()
        }
        result.data.append(payload.data)
        var adjustment = Bytes(); adjustment.u32(0xB1B0AFBA &- checksum(result.data))
        result.data.replaceSubrange(adjustmentOffset..<adjustmentOffset + 4, with: adjustment.data)
        return result.data
    }

    private static func checksum(_ data: Data) -> UInt32 {
        var bytes = Bytes(data: data); bytes.pad()
        return stride(from: 0, to: bytes.data.count, by: 4).reduce(UInt32(0)) { sum, index in
            let word = (0..<4).reduce(UInt32(0)) { ($0 << 8) | UInt32(bytes.data[index + $1]) }
            return sum &+ word
        }
    }

    private enum FontError: Error { case invalid }
    private struct Bytes {
        var data = Data()
        mutating func u16(_ value: Int) { var n = UInt16(truncatingIfNeeded: value).bigEndian; Swift.withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        mutating func u32(_ value: Int) { u32(UInt32(truncatingIfNeeded: value)) }
        mutating func u32(_ value: UInt32) { var n = value.bigEndian; Swift.withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        mutating func tag(_ value: String) { data.append(contentsOf: value.utf8) }
        mutating func pad() { while data.count % 4 != 0 { data.append(0) } }
    }
}

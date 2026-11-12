import Foundation

/// 위젯 타이머의 짝수 숫자는 사각형, 홀수 숫자는 투명하게 그리는 작은 TrueType 글꼴.
/// 빌드 도구에서만 사용한다. 생성된 글꼴을 번들에 넣어 실기기의 chronod가 읽게 한다.
enum WidgetAnimationFont {
    static func makeMask() -> Data {
        let family = "WSGIFMask"
        var tables: [String: Data] = [:]
        var head = Bytes()
        head.u32(0x00010000); head.u32(0x00010000); head.u32(0); head.u32(0x5F0F3CF5)
        head.u16(3); head.u16(1000); head.u32(0); head.u32(0); head.u32(0); head.u32(0)
        [0, 0, 1000, 1000, 0, 8, 2, 1, 0].forEach { head.u16($0) }
        tables["head"] = head.data
        var hhea = Bytes(); hhea.u32(0x00010000)
        [1000, 0, 0, 1000, 0, 0, 1000, 1, 0, 0, 0, 0, 0, 0, 0, 3].forEach { hhea.u16($0) }
        tables["hhea"] = hhea.data
        var maxp = Bytes(); maxp.u32(0x00010000)
        [3, 4, 1, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0].forEach { maxp.u16($0) }
        tables["maxp"] = maxp.data
        var hmtx = Bytes()
        for _ in 0..<3 { hmtx.u16(1000); hmtx.u16(0) }
        tables["hmtx"] = hmtx.data
        var glyf = Bytes(), loca = Bytes()
        for i in 0..<3 {
            loca.u32(glyf.data.count)
            glyf.u16(i == 2 ? 1 : 0)
            [0, 0, i == 2 ? 1000 : 0, i == 2 ? 1000 : 0].forEach { glyf.u16($0) }
            if i == 2 {
                glyf.u16(3); glyf.u16(0)
                glyf.data.append(contentsOf: [1, 1, 1, 1])
                [0, 1000, 0, -1000, 0, 0, 1000, 0].forEach { glyf.u16($0) }
            }
            glyf.pad()
        }
        loca.u32(glyf.data.count)
        tables["glyf"] = glyf.data; tables["loca"] = loca.data
        var mapping: [Int: Int] = [32: 1, 44: 1, 46: 1, 58: 1, 160: 1]
        for base in [48, 0x0660, 0x06F0, 0x0966, 0xFF10] {
            for digit in 0..<10 { mapping[base + digit] = digit % 2 == 1 ? 1 : 2 }
        }
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
            let bytes = value.data(using: .utf16BigEndian)!
            [3, 1, 0x0409, id, bytes.count, strings.data.count].forEach { name.u16($0) }
            strings.data.append(bytes)
        }
        name.data.append(strings.data); tables["name"] = name.data
        var post = Bytes(); post.u32(0x00030000); post.data.append(Data(repeating: 0, count: 28)); tables["post"] = post.data
        var os2 = Bytes()
        [3, 1000, 400, 5, 0, 650, 600, 0, 75, 650, 600, 0, 350, 50, 250, 0].forEach { os2.u16($0) }
        os2.data.append(Data(repeating: 0, count: 10))
        [1, 0, 0, 0].forEach { os2.u32($0) }
        os2.data.append(contentsOf: Array("WSTU".utf8))
        [64, 32, 65535, 1000, 0, 0, 1000, 0].forEach { os2.u16($0) }
        os2.u32(1); os2.u32(0)
        [1000, 1000, 0, 32, 1].forEach { os2.u16($0) }
        tables["OS/2"] = os2.data
        let tags = tables.keys.sorted(), tableCount = tags.count
        let tablePower = 1 << Int(log2(Double(tableCount)))
        var result = Bytes(); result.u32(0x00010000)
        [tableCount, tablePower * 16, Int(log2(Double(tablePower))), tableCount * 16 - tablePower * 16].forEach { result.u16($0) }
        var payload = Bytes(), adjustmentOffset = 0
        for tag in tags {
            let data = tables[tag]!, offset = 12 + tableCount * 16 + payload.data.count
            result.data.append(contentsOf: Array(tag.utf8)); result.u32(checksum(data)); result.u32(offset); result.u32(data.count)
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
        return stride(from: 0, to: bytes.data.count, by: 4).reduce(UInt32(0)) { sum, i in
            let word = (0..<4).reduce(UInt32(0)) { ($0 << 8) | UInt32(bytes.data[i + $1]) }
            return sum &+ word
        }
    }

    private struct Bytes {
        var data = Data()
        mutating func u16(_ value: Int) { var n = UInt16(truncatingIfNeeded: value).bigEndian; Swift.withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        mutating func u32(_ value: Int) { u32(UInt32(truncatingIfNeeded: value)) }
        mutating func u32(_ value: UInt32) { var n = value.bigEndian; Swift.withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        mutating func pad() { while data.count % 4 != 0 { data.append(0) } }
    }
}

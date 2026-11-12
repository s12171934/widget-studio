import ImageIO
import UIKit
import UniformTypeIdentifiers

/// 앱이 직접 그리는 오프라인 프리셋. 선택할 때만 GIF를 생성해 기존 가져오기 흐름으로 넘긴다.
enum GIFPreset: String, CaseIterable, Identifiable, Sendable {
    case stars, hearts, bloom, waves, neon, rain, pixels, moon
    var id: String { rawValue }

    var title: String {
        switch self {
        case .stars: return "별빛 여행"
        case .hearts: return "두근 하트"
        case .bloom: return "한밤의 꽃"
        case .waves: return "푸른 물결"
        case .neon: return "네온 궤도"
        case .rain: return "비 오는 창"
        case .pixels: return "픽셀 비트"
        case .moon: return "달빛 구름"
        }
    }

    var subtitle: String {
        switch self {
        case .stars: return "반짝이는 별과 유성"
        case .hearts: return "따뜻하게 뛰는 마음"
        case .bloom: return "천천히 회전하는 꽃잎"
        case .waves: return "겹겹이 흐르는 바다"
        case .neon: return "빛을 따라 도는 원"
        case .rain: return "차분한 빗방울"
        case .pixels: return "색이 춤추는 모자이크"
        case .moon: return "구름 사이로 빛나는 달"
        }
    }

    func makeAsset() throws -> GIFAsset {
        let data = NSMutableData()
        let count = 36
        guard let destination = CGImageDestinationCreateWithData(data, UTType.gif.identifier as CFString, count, nil) else {
            throw GIFAsset.ImportError.storage
        }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<count {
            try Task.checkCancellation()
            try autoreleasepool {
                let image = render(phase: Double(index) / Double(count) * .pi * 2)
                guard let frame = image.cgImage else { throw GIFAsset.ImportError.invalid }
                CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary:
                    [kCGImagePropertyGIFDelayTime: 0.08]] as CFDictionary)
            }
        }
        guard CGImageDestinationFinalize(destination) else { throw GIFAsset.ImportError.storage }
        return try GIFAsset(data: data as Data)
    }

    func render(phase: Double = 0) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320), format: format).image { renderer in
            let c = renderer.cgContext
            let backgrounds: [UInt32]
            switch self {
            case .stars: backgrounds = [0x0A102B, 0x3C206B]
            case .hearts: backgrounds = [0xFFF0E9, 0xF38EAA]
            case .bloom: backgrounds = [0x101735, 0x35275B]
            case .waves: backgrounds = [0x052A45, 0x148A98]
            case .neon: backgrounds = [0x070D1E, 0x161633]
            case .rain: backgrounds = [0x162D47, 0x31435B]
            case .pixels: backgrounds = [0x191638, 0x362B61]
            case .moon: backgrounds = [0x121A3C, 0x44528A]
            }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: backgrounds.map { Self.color($0) } as CFArray, locations: nil)!
            c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 320, y: 320), options: [])
            switch self {
            case .stars: drawStars(c, phase)
            case .hearts: drawHearts(c, phase)
            case .bloom: drawBloom(c, phase)
            case .waves: drawWaves(c, phase)
            case .neon: drawNeon(c, phase)
            case .rain: drawRain(c, phase)
            case .pixels: drawPixels(c, phase)
            case .moon: drawMoon(c, phase)
            }
        }
    }

    private static func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }

    private func circle(_ c: CGContext, x: Double, y: Double, radius: Double, color: UInt32, alpha: Double = 1) {
        c.setFillColor(Self.color(color, alpha: alpha))
        c.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    private func drawStars(_ c: CGContext, _ phase: Double) {
        for i in 0..<35 {
            let x = Double((i * 83 + 17) % 310 + 5), y = Double((i * 47 + 29) % 310 + 5)
            let alpha = 0.25 + 0.65 * (sin(phase + Double(i) * 1.7) + 1) / 2
            circle(c, x: x, y: y, radius: i % 5 == 0 ? 2 : 1, color: 0xE2E6FF, alpha: alpha)
            if i % 9 == 0 {
                c.setStrokeColor(Self.color(0xD9BFFF, alpha: alpha * 0.7))
                c.setLineWidth(1)
                c.move(to: CGPoint(x: x - 5, y: y)); c.addLine(to: CGPoint(x: x + 5, y: y))
                c.move(to: CGPoint(x: x, y: y - 5)); c.addLine(to: CGPoint(x: x, y: y + 5)); c.strokePath()
            }
        }
        for i in stride(from: 22, through: 0, by: -1) {
            let angle = phase - Double(i) * 0.04
            circle(c, x: 160 + cos(angle) * 98, y: 150 + sin(angle) * 74,
                   radius: 4 - Double(i) * 0.12, color: 0xC3D5FF, alpha: 1 - Double(i) / 24)
        }
        circle(c, x: 160 + cos(phase) * 98, y: 150 + sin(phase) * 74, radius: 4, color: 0xFFFFFF)
    }

    private func heart(_ c: CGContext, x: Double, y: Double, scale: Double, color: UInt32, alpha: Double) {
        c.saveGState()
        c.translateBy(x: x, y: y); c.scaleBy(x: scale, y: scale)
        c.move(to: CGPoint(x: 0, y: 0.45))
        c.addCurve(to: CGPoint(x: 0, y: -0.3), control1: CGPoint(x: -1, y: -0.1), control2: CGPoint(x: -0.5, y: -0.9))
        c.addCurve(to: CGPoint(x: 0, y: 0.45), control1: CGPoint(x: 0.5, y: -0.9), control2: CGPoint(x: 1, y: -0.1))
        c.setFillColor(Self.color(color, alpha: alpha)); c.fillPath()
        c.restoreGState()
    }

    private func drawHearts(_ c: CGContext, _ phase: Double) {
        for i in 0..<10 {
            let y = (Double(i * 59) - phase / (.pi * 2) * 400 + 800).truncatingRemainder(dividingBy: 400) - 40
            heart(c, x: Double((i * 79 + 25) % 320), y: y, scale: 13 + Double(i % 3) * 7,
                  color: 0xFFFFFF, alpha: 0.2)
        }
        let pulse = 1 + sin(phase) * 0.07
        c.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: Self.color(0xB83268, alpha: 0.22))
        heart(c, x: 160, y: 172, scale: 115 * pulse, color: 0xEA527B, alpha: 1)
        c.setShadow(offset: .zero, blur: 0, color: nil)
        heart(c, x: 150, y: 157, scale: 86 * pulse, color: 0xFF7F9A, alpha: 0.7)
    }

    private func drawBloom(_ c: CGContext, _ phase: Double) {
        c.saveGState()
        c.translateBy(x: 160, y: 154)
        c.rotate(by: phase / 8)
        c.setBlendMode(.screen)
        for ring in 0..<2 {
            for i in 0..<8 {
                c.saveGState()
                c.rotate(by: Double(i) * .pi / 4 + Double(ring) * .pi / 8)
                c.setFillColor(Self.color(ring == 0 ? 0xA78BFA : 0x5DE4DA, alpha: ring == 0 ? 0.5 : 0.35))
                let reach = ring == 0 ? 105.0 : 78.0
                c.fillEllipse(in: CGRect(x: -29, y: -reach, width: 58, height: reach + 18))
                c.restoreGState()
            }
        }
        circle(c, x: 0, y: 0, radius: 19 + sin(phase) * 3, color: 0xFFF1BB)
        c.restoreGState()
    }

    private func drawWaves(_ c: CGContext, _ phase: Double) {
        let colors: [UInt32] = [0x1B7190, 0x2BA7B5, 0x68D1CC, 0xC0ECE1]
        for layer in 0..<4 {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 320))
            for x in stride(from: 0, through: 320, by: 4) {
                let y = 115 + Double(layer) * 39 + sin(Double(x) / 320 * .pi * 2 + phase + Double(layer)) * 16
                    + sin(Double(x) / 320 * .pi * 4 - phase) * 5
                path.addLine(to: CGPoint(x: Double(x), y: y))
            }
            path.addLine(to: CGPoint(x: 320, y: 320)); path.closeSubpath()
            c.setFillColor(Self.color(colors[layer])); c.addPath(path); c.fillPath()
        }
    }

    private func drawNeon(_ c: CGContext, _ phase: Double) {
        let colors: [UInt32] = [0x8F8BFF, 0x42E2DB, 0xFF70AC]
        for ring in 0..<3 {
            let r = Double(54 + ring * 35)
            c.setStrokeColor(Self.color(colors[ring], alpha: 0.17)); c.setLineWidth(2)
            c.strokeEllipse(in: CGRect(x: 160 - r, y: 160 - r, width: r * 2, height: r * 2))
            for i in stride(from: 28, through: 0, by: -1) {
                let angle = phase * (ring == 1 ? -1 : 1) + Double(ring) * 2 - Double(i) * 0.035
                circle(c, x: 160 + cos(angle) * r, y: 160 + sin(angle) * r,
                       radius: 3.5, color: colors[ring], alpha: 1 - Double(i) / 30)
            }
        }
    }

    private func drawRain(_ c: CGContext, _ phase: Double) {
        circle(c, x: 248, y: 73, radius: 30, color: 0xD5E3E8, alpha: 0.2)
        for i in 0..<25 {
            let x = Double((i * 43 + 11) % 350)
            let y = (Double(i * 71) + phase / (.pi * 2) * 400).truncatingRemainder(dividingBy: 400) - 40
            c.setStrokeColor(Self.color(0xC3E8F3, alpha: 0.18 + Double(i % 4) * 0.08)); c.setLineWidth(1.5)
            c.move(to: CGPoint(x: x, y: y)); c.addLine(to: CGPoint(x: x - 7, y: y + 24)); c.strokePath()
        }
        for i in 0..<3 {
            let progress = (phase / (.pi * 2) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let r = 8 + progress * 38
            c.setStrokeColor(Self.color(0xA6D7E3, alpha: (1 - progress) * 0.5)); c.setLineWidth(1)
            c.strokeEllipse(in: CGRect(x: 75 + Double(i) * 75 - r, y: 260 - r / 4, width: r * 2, height: r / 2))
        }
    }

    private func drawPixels(_ c: CGContext, _ phase: Double) {
        let colors: [UInt32] = [0x9C8BFF, 0xFF8CA8, 0x6ADBC5, 0xFFD897]
        for y in 0..<10 {
            for x in 0..<10 {
                let pulse = (sin(phase + Double(x) * 0.65 + Double(y) * 0.48) + 1) / 2
                let side = 10 + pulse * 13
                let rect = CGRect(x: Double(x) * 28 + 34 - side / 2, y: Double(y) * 28 + 34 - side / 2, width: side, height: side)
                c.setFillColor(Self.color(colors[(x + y) % 4], alpha: 0.35 + pulse * 0.65))
                c.addPath(CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)); c.fillPath()
            }
        }
    }

    private func drawMoon(_ c: CGContext, _ phase: Double) {
        c.setShadow(offset: .zero, blur: 24, color: Self.color(0xFFE3A3, alpha: 0.45))
        circle(c, x: 190, y: 119, radius: 49, color: 0xFFEBC3)
        c.setShadow(offset: .zero, blur: 0, color: nil)
        circle(c, x: 177, y: 103, radius: 8, color: 0xE6C992, alpha: 0.35)
        circle(c, x: 210, y: 134, radius: 12, color: 0xE6C992, alpha: 0.25)
        for i in 0..<18 {
            circle(c, x: Double((i * 83 + 9) % 320), y: Double((i * 31 + 12) % 190), radius: 1,
                   color: 0xEEF0FF, alpha: 0.4 + sin(phase + Double(i)) * 0.2)
        }
        for layer in 0..<2 {
            let offset = phase / (.pi * 2) * 440 * (layer == 0 ? 1 : -1)
            for i in -2...2 {
                let x = Double(i) * 440 + offset + Double(layer) * 120
                let y = Double(205 + layer * 46)
                c.setFillColor(Self.color(layer == 0 ? 0x8C9AC7 : 0x5F71A4, alpha: 0.72))
                c.fillEllipse(in: CGRect(x: x, y: y, width: 190, height: 58))
                c.fillEllipse(in: CGRect(x: x + 33, y: y - 23, width: 100, height: 75))
                c.fillEllipse(in: CGRect(x: x + 103, y: y - 9, width: 125, height: 60))
            }
        }
    }
}

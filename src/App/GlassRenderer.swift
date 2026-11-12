import CoreImage
import SwiftUI
import UIKit

/// 홈 화면 스크린샷에서 위젯 자리를 잘라 흐리게 만든 배경 그림을 만든다.
/// 위젯은 배경화면을 볼 수 없어서, 이 그림을 깔아 투명(클리어)처럼 보이게 한다.
enum GlassRenderer {
    private static let context = CIContext()

    static var screenSize: CGSize {
        let s = UIScreen.main.bounds.size
        return CGSize(width: min(s.width, s.height), height: max(s.width, s.height))
    }

    /// 위젯 표시 크기(pt). 위젯이 한 번이라도 그려졌으면 그 실제 값을, 아니면 화면 폭 비율로 추정한다.
    static func widgetSize(_ family: GlassFamily) -> CGSize {
        if let recorded = DesignStore.widgetSize(family: family) { return recorded }
        let w = screenSize.width
        let small = (w * 0.4229).rounded()
        switch family {
        case .small: return CGSize(width: small, height: small)
        case .medium: return CGSize(width: (w * 0.9055).rounded(), height: small)
        case .large: return CGSize(width: (w * 0.9055).rounded(), height: (w * 0.950).rounded())
        }
    }

    /// 정규화된 자리 크기(스크린샷 기준 0~1).
    static func normalizedSize(_ family: GlassFamily) -> CGSize {
        let size = widgetSize(family)
        return CGSize(width: size.width / screenSize.width, height: size.height / screenSize.height)
    }

    /// 처음 자리를 맞출 때의 기본 위치 — 위쪽 가운데.
    static func defaultRect(_ family: GlassFamily) -> GlassRect {
        let n = normalizedSize(family)
        return GlassRect(CGRect(x: (1 - n.width) / 2, y: 0.12, width: n.width, height: n.height))
    }

    /// 이 아이폰 화면 비율과 맞는 스크린샷인지.
    static func matchesScreen(_ image: UIImage) -> Bool {
        let a = image.size.width / image.size.height
        let b = screenSize.width / screenSize.height
        return abs(a - b) / b < 0.02
    }

    /// 자리 하나를 잘라 흐리게·어둡게 만든다. blur 는 위젯 기준 pt.
    /// compensateFilm: 홈 화면이 위젯 위에 덮는 옅은 막을 미리 상쇄한다(위젯용). 앱 안 미리보기에는 끈다.
    static func render(wallpaper: UIImage, rect: GlassRect, blur: Double, dim: Double,
                       maxSide: CGFloat = 1100, compensateFilm: Bool = true) -> UIImage? {
        let upright = wallpaper.uprighted()
        guard let cg = upright.cgImage else { return nil }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let px = CGRect(x: rect.x * W, y: rect.y * H, width: rect.w * W, height: rect.h * H)
            .integral.intersection(CGRect(x: 0, y: 0, width: W, height: H))
        guard px.width > 4, px.height > 4, let cropped = cg.cropping(to: px) else { return nil }

        // pt → 픽셀 환산: 스크린샷 폭이 화면 폭(pt) 몇 배인지.
        let pxPerPt = W / screenSize.width
        var image = CIImage(cgImage: cropped)
        if blur > 0.1 {
            let extent = image.extent
            image = image.clampedToExtent()
                .applyingGaussianBlur(sigma: blur * pxPerPt / 2)
                .cropped(to: extent)
        }
        guard let out = context.createCGImage(image, from: image.extent) else { return nil }

        let scale = min(1, maxSide / max(px.width, px.height))
        let w = Int((px.width * scale).rounded()), h = Int((px.height * scale).rounded())
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(out, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let buffer = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

        // sRGB 값 그대로: 어둡게(dim) 한 뒤, 시스템 막을 미리 거꾸로 걷어 낸다.
        let keep = 1 - dim
        let film = compensateFilm ? SystemWidgetFilm.self : nil
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            for c in 0..<3 {
                var v = Double(buffer[i + c]) * keep
                if let film { v = (v - film.alpha * film.color[c]) / (1 - film.alpha) }
                buffer[i + c] = UInt8(min(max(v, 0), 255).rounded())
            }
        }
        return ctx.makeImage().map { UIImage(cgImage: $0) }
    }

    /// 디자인의 자리마다 배경 그림을 다시 만든다. 자리를 지운 크기는 그림도 지운다.
    static func renderAll(_ design: WidgetDesign, wallpaper: UIImage? = DesignStore.loadWallpaper()) {
        for family in GlassFamily.allCases {
            guard design.usesGlass, let wallpaper, let rect = design.glassRects[family.rawValue],
                  let image = render(wallpaper: wallpaper, rect: rect, blur: design.glassBlur, dim: design.glassDim)
            else {
                DesignStore.deleteGlassBackground(for: design.id, family: family)
                continue
            }
            DesignStore.saveGlassBackground(image, for: design.id, family: family)
        }
    }
}

/// iOS 홈 화면은 기본(전체 색) 모드에서 위젯 위에 옅은 밝은 막을 덮는다.
/// iOS 27.2 시뮬레이터에서 위젯 전후 화면을 회귀해 잰 값(라이트·다크 모두 불투명도 약 0.099).
/// 이 막 때문에 잘라 깐 배경화면이 주변보다 뿌옇게 떠 보여, 그림을 만들 때 미리 거꾸로 걷어 낸다.
enum SystemWidgetFilm {
    static let alpha = 0.099
    static let color: [Double] = [228, 226, 229]
}

extension UIImage {
    /// 회전 정보(imageOrientation)를 픽셀에 반영해, cgImage 를 그대로 잘라도 되게 한다.
    func uprighted() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

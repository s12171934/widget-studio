import Foundation

/// 위젯 크기별 사진·GIF 표시 범위. 위치는 중앙에서 각 가장자리까지의 비율(-1...1)이다.
struct WidgetImageLayout: Codable, Hashable {
    enum Mode: String, Codable, CaseIterable, Identifiable {
        case fill, fit
        var id: String { rawValue }
        var label: String { self == .fill ? "채우기" : "전체 보기" }
    }

    var mode: Mode = .fill
    var zoom: Double = 1
    var horizontal: Double = 0
    var vertical: Double = 0

    func imageRect(image: CGSize, viewport: CGSize) -> CGRect {
        let width = max(1, viewport.width), height = max(1, viewport.height)
        let imageWidth = max(1, image.width), imageHeight = max(1, image.height)
        let xScale = width / imageWidth, yScale = height / imageHeight
        let factor = (mode == .fill ? max(xScale, yScale) : min(xScale, yScale))
            * bounded(zoom, in: 1...3, fallback: 1)
        let size = CGSize(width: imageWidth * factor, height: imageHeight * factor)
        let x = bounded(horizontal, in: -1...1) * abs(size.width - width) / 2
        let y = bounded(vertical, in: -1...1) * abs(size.height - height) / 2
        return CGRect(x: (width - size.width) / 2 + x, y: (height - size.height) / 2 + y,
                      width: size.width, height: size.height)
    }

    private func bounded(_ value: Double, in range: ClosedRange<Double>, fallback: Double = 0) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
}

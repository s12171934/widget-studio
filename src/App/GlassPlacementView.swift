import SwiftUI
import WidgetKit

/// 빈 홈 화면 스크린샷 위에서 위젯을 놓을 자리를 맞춘다.
/// 사각형을 끌어 위젯이 놓인 자리에 겹치면, 그 자리의 배경화면이 위젯 배경이 된다.
struct GlassPlacementView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var design: WidgetDesign
    let family: GlassFamily
    let wallpaper: UIImage

    @State private var rect: GlassRect
    @State private var dragStart: GlassRect?

    init(design: Binding<WidgetDesign>, family: GlassFamily, wallpaper: UIImage) {
        _design = design
        self.family = family
        self.wallpaper = wallpaper
        _rect = State(initialValue: design.wrappedValue.glassRects[family.rawValue]
                      ?? GlassRenderer.defaultRect(family))
    }

    private var widgetFamily: WidgetFamily {
        switch family {
        case .small: return .systemSmall
        case .medium: return .systemMedium
        case .large: return .systemLarge
        }
    }

    var body: some View {
        GeometryReader { geo in
            // 스크린샷은 이 기기 화면과 같은 비율이라 화면 전체에 그대로 깔면 실제 자리와 겹친다.
            let D = geo.size
            let frame = CGRect(x: rect.x * D.width, y: rect.y * D.height,
                               width: rect.w * D.width, height: rect.h * D.height)
            let radius = 24 * D.width / GlassRenderer.screenSize.width

            ZStack(alignment: .topLeading) {
                Image(uiImage: wallpaper)
                    .resizable()
                    .frame(width: D.width, height: D.height)

                // 자리 미리보기: 그 자리의 배경화면을 흐리게 + 유리 테두리 + 디자인 내용.
                Image(uiImage: wallpaper)
                    .resizable()
                    .frame(width: D.width, height: D.height)
                    .offset(x: -frame.minX, y: -frame.minY)
                    .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                    .blur(radius: design.glassBlur * D.width / GlassRenderer.screenSize.width,
                          opaque: true)
                    .overlay(Color.black.opacity(design.glassDim))
                    .overlay {
                        ZStack {
                            LinearGradient(colors: [.white.opacity(0.10), .clear],
                                           startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.22))
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.15),
                                                                      .white.opacity(0.35)],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing),
                                              lineWidth: 1.5)
                            DesignContent(design: design, family: widgetFamily, date: .now)
                                .padding(16)
                                .frame(width: GlassRenderer.widgetSize(family).width,
                                       height: GlassRenderer.widgetSize(family).height)
                                .scaleEffect(D.width / GlassRenderer.screenSize.width)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .shadow(color: .black.opacity(dragStart == nil ? 0 : 0.3), radius: 12)
                    .offset(x: frame.minX, y: frame.minY)
                    .gesture(
                        DragGesture()
                            .onChanged { g in
                                let start = dragStart ?? rect
                                if dragStart == nil { dragStart = rect }
                                move(from: start, dx: g.translation.width / D.width,
                                     dy: g.translation.height / D.height)
                            }
                            .onEnded { _ in dragStart = nil }
                    )
                    .animation(.interactiveSpring, value: rect)
            }
            .frame(width: D.width, height: D.height)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { controls }
        .overlay(alignment: .top) { header }
        .statusBarHidden()
    }

    // MARK: 조작

    private func move(from start: GlassRect, dx: Double, dy: Double) {
        var r = start
        r.x = min(max(start.x + dx, 0), 1 - r.w)
        r.y = min(max(start.y + dy, 0), 1 - r.h)
        rect = r
    }

    private func nudge(_ dxPt: Double, _ dyPt: Double) {
        let s = GlassRenderer.screenSize
        move(from: rect, dx: dxPt / s.width, dy: dyPt / s.height)
    }

    private var header: some View {
        HStack {
            Button("취소", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            Spacer()
            Text("\(family.label) 위젯 자리")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
            Spacer()
            Button("완료", systemImage: "checkmark") {
                design.glassRects[family.rawValue] = rect
                dismiss()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                Text("사각형을 끌어 홈 화면에서 위젯이 놓인 자리에 맞추세요")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    nudgeButton("arrow.left") { nudge(-1, 0) }
                    nudgeButton("arrow.up") { nudge(0, -1) }
                    nudgeButton("arrow.down") { nudge(0, 1) }
                    nudgeButton("arrow.right") { nudge(1, 0) }
                }
                LabeledSlider(title: "흐림", value: $design.glassBlur, range: 0...20)
                LabeledSlider(title: "어둡게", value: $design.glassDim, range: 0...0.5)
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    private func nudgeButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 44, height: 36)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(title).font(.footnote).frame(width: 44, alignment: .leading)
            Slider(value: $value, in: range)
        }
    }
}

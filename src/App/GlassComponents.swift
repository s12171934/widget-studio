import SwiftUI

// MARK: - 배경화면

/// Liquid Glass 는 뒤에 비치는 것이 있어야 살아난다.
/// 홈 화면 배경화면을 흉내 낸 메시 그라데이션을 앱 화면 뒤에 깐다.
struct Wallpaper: View {
    enum Style: String, CaseIterable, Identifiable {
        case dusk, ocean, bloom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .dusk: return "노을"
            case .ocean: return "바다"
            case .bloom: return "꽃"
            }
        }
        /// 배경화면 위 글자·막대가 읽히도록 앱의 라이트/다크를 배경화면에 맞춘다.
        var colorScheme: ColorScheme { self == .bloom ? .light : .dark }
        var colors: [Color] {
            switch self {
            case .dusk:
                return [.init(hex: "#1E1B4B"), .init(hex: "#4C1D95"), .init(hex: "#0F172A"),
                        .init(hex: "#BE185D"), .init(hex: "#F97316"), .init(hex: "#6D28D9"),
                        .init(hex: "#FDBA74"), .init(hex: "#F472B6"), .init(hex: "#312E81")]
            case .ocean:
                return [.init(hex: "#0C4A6E"), .init(hex: "#0369A1"), .init(hex: "#164E63"),
                        .init(hex: "#0891B2"), .init(hex: "#22D3EE"), .init(hex: "#1D4ED8"),
                        .init(hex: "#A5F3FC"), .init(hex: "#38BDF8"), .init(hex: "#1E3A8A")]
            case .bloom:
                return [.init(hex: "#FDF2F8"), .init(hex: "#FBCFE8"), .init(hex: "#FEF3C7"),
                        .init(hex: "#F9A8D4"), .init(hex: "#C084FC"), .init(hex: "#FDE68A"),
                        .init(hex: "#A5B4FC"), .init(hex: "#F0ABFC"), .init(hex: "#FECACA")]
            }
        }
    }

    var style: Style = .dusk

    var body: some View {
        MeshGradient(width: 3, height: 3,
                     points: [[0, 0], [0.5, 0], [1, 0],
                              [0, 0.5], [0.62, 0.42], [1, 0.5],
                              [0, 1], [0.45, 1], [1, 1]],
                     colors: style.colors)
            .ignoresSafeArea()
    }
}

// MARK: - 유리 세그먼트

/// 유리 캡슐 안에서 선택 표시가 옵션 사이를 물방울처럼 옮겨 다니는 선택기.
/// 선택 표시는 하나의 glassEffectID 를 가져서, 선택이 바뀌면 유리가 녹아 이동한다.
struct GlassSegmented<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var tint: Color = .accentColor

    @Namespace private var ns

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(options, id: \.self) { option in
                    let isOn = option == selection
                    Button {
                        withAnimation(.bouncy(duration: 0.35)) { selection = option }
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(isOn ? .semibold : .regular))
                            .foregroundStyle(isOn ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .background {
                        if isOn {
                            Capsule()
                                .fill(.clear)
                                .glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                                .glassEffectID("selection", in: ns)
                        }
                    }
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
        }
    }
}

// MARK: - 유리 색 견본

/// 색을 입힌 유리 방울. 누르면 유리가 눌림 반응(interactive)을 보인다.
struct GlassSwatch: View {
    let hex: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(Color(hex: hex).isLight ? .black : .white)
                .opacity(selected ? 1 : 0)
                .frame(width: 38, height: 38)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Color(hex: hex).opacity(0.85)).interactive(), in: .circle)
        .scaleEffect(selected ? 1.12 : 1)
        .animation(.bouncy, value: selected)
    }
}

import SwiftUI
import UIKit
import WidgetKit

// Timer/font layering adapted from https://github.com/NAOYA-MAEDA-DEV/WidgetKitAnimation
// MIT License — Copyright (c) 2026 Naoya Maeda
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/// 그림은 보통 Image로 전달하고, 번들에 포함한 숫자 마스크만 시스템 타이머로 갱신한다.
/// 원본 GIF 재생기·앱 프로세스·잦은 타임라인 갱신 없이 홈 화면에서 16장면을 2초마다 반복한다.
struct GIFWidgetAnimationView: View {
    let frames: [UIImage]
    let anchor: Date
    let glass: Bool
    let layout: WidgetImageLayout

    var body: some View {
        GeometryReader { geometry in
            let side = max(geometry.size.width, geometry.size.height)
            ZStack {
                frames(0..<8, viewport: geometry.size, side: side)
                frames(8..<16, viewport: geometry.size, side: side)
                    .mask(blink(offset: 1, side: side))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
        .environment(\.locale, Locale(identifier: "en_US_POSIX"))
        .accessibilityLabel("GIF, 홈 화면에서 반복 재생")
    }

    private func frames(_ range: Range<Int>, viewport: CGSize, side: CGFloat) -> some View {
        ZStack {
            ForEach(range, id: \.self) { index in
                frame(index, viewport: viewport, side: side)
            }
        }
    }

    @ViewBuilder
    private func frame(_ index: Int, viewport: CGSize, side: CGFloat) -> some View {
        let image = WidgetImageView(image: frames[index], layout: layout, glass: glass)
            .frame(width: viewport.width, height: viewport.height)
        if index == 0 {
            image
        } else {
            image.mask(blink(offset: -Double(index) / 8, side: side))
        }
    }

    private func blink(offset: TimeInterval, side: CGFloat) -> some View {
        GeometryReader { _ in
            Text(anchor.addingTimeInterval(-offset), style: .timer)
                .font(.custom("WSGIFMask-Regular", fixedSize: side))
                .foregroundStyle(.white)
                .frame(width: side * 9, height: side)
                .multilineTextAlignment(.trailing)
                .offset(x: -side * 8)
        }
        .clipped()
    }
}

import SwiftUI

/// #151 提案3: 装飾アイコン (Splash のコイン・ロゴ、空状態アイコン) を
/// Dynamic Type に「上限つき」で追従させるための倍率ルール。
///
/// 装飾は文字ほど大きくする必要がないので、1.3 倍で止める。チュートリアルの大きなアイコンも
/// このルールで追従する (縦スクロールが無かった頃は AX 最大で説明文と「スキップ」を画面外へ
/// 押し出したため固定にしていたが、#246 で本文が縦スクロールになり、画面内に残ることを実測した)。
enum DecorativeScale {
    static let maxFactor: CGFloat = 1.3

    /// `@ScaledMetric` から得た生の倍率を 1.0〜maxFactor に clamp して base に掛ける。
    /// 下限 1.0 は「小さい文字設定でも今より縮めない」ため (RecordCalendarView の floor と同じ)。
    static func size(base: CGFloat, rawFactor: CGFloat) -> CGFloat {
        base * min(max(rawFactor, 1), maxFactor)
    }
}

/// 倍率は largeTitle 基準で読む。基準値を 100 にして /100 するのは、基準値 1 だと
/// 丸めが入った場合に倍率が 1 か 2 しか取れなくなるため。
private struct DecorativeFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @ScaledMetric(relativeTo: .largeTitle) private var scaledHundred: CGFloat = 100

    func body(content: Content) -> some View {
        content.font(.system(
            size: DecorativeScale.size(base: size, rawFactor: scaledHundred / 100),
            weight: weight,
            design: design
        ))
    }
}

private struct DecorativeFrameModifier: ViewModifier {
    let size: CGFloat
    @ScaledMetric(relativeTo: .largeTitle) private var scaledHundred: CGFloat = 100

    func body(content: Content) -> some View {
        let side = DecorativeScale.size(base: size, rawFactor: scaledHundred / 100)
        return content.frame(width: side, height: side)
    }
}

extension View {
    /// 装飾アイコン / ロゴ用のフォント。既定サイズでは `size` そのもの、最大 1.3 倍まで育つ。
    func decorativeFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(DecorativeFontModifier(size: size, weight: weight, design: design))
    }

    /// 装飾アイコンを載せる円などの正方形 frame。`decorativeFont` と同じ倍率で育つので、
    /// 円の中のアイコンが円からはみ出さない。
    func decorativeFrame(size: CGFloat) -> some View {
        modifier(DecorativeFrameModifier(size: size))
    }
}

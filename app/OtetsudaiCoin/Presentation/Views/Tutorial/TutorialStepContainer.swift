import SwiftUI

/// チュートリアル本文の置き場所 (Issue #246)。
///
/// 縦に収まるときは今までどおり上下の `Spacer` で中央に置き、収まらないとき
/// (AX サイズの Dynamic Type など) だけ本文を縦スクロールにする。下のナビゲーション
/// (戻る / 次へ / スキップ) はこの外に置くので、常に画面内に残る。
///
/// - `ViewThatFits` を使うのは、既定サイズで今のレイアウトがそのまま選ばれ、見た目を
///   変えないため (`ScrollView` + `minHeight` 方式は既定サイズで差分が出た。#246 の spike で実測)。
/// - `.id(step)` で、ステップが変わるたびにスクロール位置を先頭へ戻す
///   (前のステップでスクロールした位置が引き継がれ、見出しが隠れたまま始まるのを防ぐ)。
struct TutorialStepContainer<Content: View>: View {
    let step: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                Spacer()
                content()
                Spacer()
            }
            ScrollView {
                content()
            }
            .id(step)
        }
    }
}

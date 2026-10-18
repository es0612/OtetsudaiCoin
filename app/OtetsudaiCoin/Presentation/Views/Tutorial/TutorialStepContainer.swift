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
/// - `scrollTarget` が変わったら、その `.id` の view の下端が見えるところまでスクロールする
///   (AX サイズで一番下のカードを選んだとき、すぐ下に出る「記録する」の帯へ連れて行く。#262)。
///   `ScrollViewReader` は `ViewThatFits` の外側で包み、既定サイズの「収まるか」の判定を変えない。
struct TutorialStepContainer<Content: View>: View {
    let step: Int
    var scrollTarget: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollViewReader { proxy in
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
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation {
                    proxy.scrollTo(target, anchor: .bottom)
                }
            }
        }
    }
}

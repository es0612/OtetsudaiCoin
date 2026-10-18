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
/// - `scrollSerial` が進んだときも同じ先へスクロールし直す。スクロール先の文字列だけを見ていると、
///   選択済みのカードをもう一度押したときや、ステップを 3 → 2 → 3 と戻ったとき (本文は先頭へ戻る) に
///   値が変わらず `onChange` が発火しなかった (#265)。
struct TutorialStepContainer<Content: View>: View {
    let step: Int
    var scrollTarget: String? = nil
    var scrollSerial: Int = 0
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
            .onChange(of: TutorialScrollRequest(target: scrollTarget, serial: scrollSerial)) { _, request in
                guard let target = request.target else { return }
                withAnimation {
                    proxy.scrollTo(target, anchor: .bottom)
                }
            }
        }
    }
}

/// `TutorialStepContainer` がスクロールするきっかけ。スクロール先が同じでも `serial` が進めば別の値になる (#265)。
struct TutorialScrollRequest: Equatable {
    let target: String?
    let serial: Int
}

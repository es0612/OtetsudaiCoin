import SwiftUI

/// おまけを払った直後に子どもへ見せる演出 (#279)。
///
/// 勝手には消えない（親が子に見せてから「閉じる」を押す）。`.sheet` ではなく親の `.overlay` で出す。
struct BonusCelebrationView: View {
    let bonus: PaymentBonus
    let onClose: () -> Void

    // 開始値は描画される状態として持ち、onAppear では最終値だけをアニメーション付きで書く
    // (同じ更新の中で開始値と最終値を両方書くと、開始値は一度も描画されない)
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motion: MotionPlan { .make(reduceMotion: reduceMotion) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(bonus.stamp.emoji)
                        .decorativeFont(size: 96, weight: .regular, design: .rounded)
                    Text(bonus.stamp.title)
                        .appFont(.sectionHeader)
                        .foregroundColor(AccessibilityColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("+¥\(bonus.amount)")
                        .appFont(.appTitle)
                        .foregroundColor(AccessibilityColors.successGreen)
                }
                .accessibilityElement(children: .combine)

                Button {
                    onClose()
                } label: {
                    Text("閉じる")
                        .frame(maxWidth: .infinity)
                }
                .primaryButton()
                .accessibilityIdentifier("bonus_celebration_close")
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(AccessibilityColors.cardBackgroundGrouped)
            .cornerRadius(AppRadius.large)
            .padding(24)
            .scaleEffect(appeared ? 1.0 : motion.initialScale)
            .opacity(appeared ? 1.0 : 0)
        }
        // VoiceOver のフォーカスを演出の中に閉じ込める（下の月移動ボタンへ行かせない）
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("bonus_celebration")
        .onAppear {
            withAnimation(motion.entrance) {
                appeared = true
            }
        }
    }
}

extension BonusCelebrationView {
    /// 動きの組み立て。「視差効果を減らす」が ON のときは拡大せず、フェードだけにする
    /// (`SplashScreenView.MotionPlan` と同じ形)。
    struct MotionPlan {
        let initialScale: CGFloat
        let entrance: Animation

        static func make(reduceMotion: Bool) -> MotionPlan {
            if reduceMotion {
                return MotionPlan(initialScale: 1.0, entrance: .easeOut(duration: 0.3))
            }
            return MotionPlan(
                initialScale: 0.6,
                entrance: .spring(response: 0.6, dampingFraction: 0.65)
            )
        }
    }
}

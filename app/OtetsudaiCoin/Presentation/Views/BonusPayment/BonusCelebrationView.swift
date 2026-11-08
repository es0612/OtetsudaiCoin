import SwiftUI

/// おまけを払った直後に子どもへ見せる演出 (#279)。
///
/// 勝手には消えない（親が子に見せてから「閉じる」を押す）。`.sheet` ではなく親の `.overlay` で出す。
struct BonusCelebrationView: View {
    let bonus: PaymentBonus
    let onClose: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0
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
            .background(Color(.systemBackground))
            .cornerRadius(AppRadius.large)
            .padding(24)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .accessibilityIdentifier("bonus_celebration")
        .onAppear {
            scale = motion.initialScale
            withAnimation(motion.entrance) {
                scale = 1.0
                opacity = 1.0
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

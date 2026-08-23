import SwiftUI

/// displayIcon 絵文字 + 選択状態の円塗りを表示する共通アイコン (#200)。
///
/// TaskCardView / TutorialTaskCardView / TaskSelectionRow で verbatim 重複していた
/// ZStack + Circle + Text を集約する。tint / font 変更時の追随がここ 1 箇所で済む。
///
/// - ZStack + 非拘束 Text: 固定 frame + overlay/background だと AX サイズの
///   Dynamic Type で絵文字が truncate する (#177 PR #198 で確立したパターン)。
/// - 絵文字は装飾。意味は隣接する displayName の Text が担うため VoiceOver から隠す (#84 パターン)。
struct TaskIconView: View {
    let task: HelpTask
    let isSelected: Bool
    var size: CGFloat = 50
    var font: Font = .title2

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected
                    ? AccessibilityColors.taskIconSelectedFill
                    : AccessibilityColors.taskIconUnselectedFill)
                .frame(width: size, height: size)

            Text(task.displayIcon)
                .font(font)
                .accessibilityHidden(true)
        }
    }
}

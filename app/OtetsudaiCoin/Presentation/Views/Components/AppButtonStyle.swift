import SwiftUI

// MARK: - 単色ソフト角丸ボタンスタイル (Issue #147: 青→紫グラデ廃止)

/// ブランドカラー単色 + ソフト角丸 (AppRadius.xLarge) のボタンスタイル。
/// 旧 GradientButtonStyle の後継。押下時の縮小アニメーションは踏襲し、グローは廃止。
struct SolidButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let isDisabled: Bool

    init(backgroundColor: Color = AccessibilityColors.brandPrimary, isDisabled: Bool = false) {
        self.backgroundColor = backgroundColor
        self.isDisabled = isDisabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(isDisabled ? Color.gray.opacity(0.6) : backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xLarge))
            .appShadow(isDisabled ? AppShadowStyle(color: .clear, radius: 0, x: 0, y: 0) : AppShadow.cardElevated)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - プリセットスタイル

extension SolidButtonStyle {
    /// メイン CTA (ブランドオレンジ)
    static let primary = SolidButtonStyle(backgroundColor: AccessibilityColors.brandPrimary)
    /// 記録・保存など成功系アクション (ティール)
    static let success = SolidButtonStyle(backgroundColor: AccessibilityColors.brandSecondary)
    /// 削除など破壊的アクション (エラーレッド)
    static let destructive = SolidButtonStyle(backgroundColor: AccessibilityColors.errorRed)
}

// MARK: - View Extension

extension View {
    func primaryButton(isDisabled: Bool = false) -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.brandPrimary, isDisabled: isDisabled))
    }

    func successButton(isDisabled: Bool = false) -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.brandSecondary, isDisabled: isDisabled))
    }

    func destructiveButton(isDisabled: Bool = false) -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.errorRed, isDisabled: isDisabled))
    }
}

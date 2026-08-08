import SwiftUI

// MARK: - 単色ソフト角丸ボタンスタイル (Issue #147: 青→紫グラデ廃止)

/// ブランドカラー単色 + ソフト角丸 (AppRadius.xLarge) のボタンスタイル。
/// 旧グラデーションボタンスタイルの後継。押下時の縮小アニメーションは踏襲し、グローは廃止。
/// 無効状態は `.disabled(_:)` からの `\.isEnabled` 環境値で自動追随する (#175 Finding 4)。
struct SolidButtonStyle: ButtonStyle {
    let backgroundColor: Color

    @Environment(\.isEnabled) private var isEnabled

    init(backgroundColor: Color = AccessibilityColors.brandPrimary) {
        self.backgroundColor = backgroundColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Self.background(for: backgroundColor, isEnabled: isEnabled))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xLarge))
            .appShadow(Self.shadow(isEnabled: isEnabled))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(Self.opacity(isEnabled: isEnabled))
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 有効/無効の見た目マッピング (pure helper — unit test 対象)

extension SolidButtonStyle {
    static func background(for backgroundColor: Color, isEnabled: Bool) -> Color {
        isEnabled ? backgroundColor : Color.gray.opacity(0.6)
    }

    static func opacity(isEnabled: Bool) -> Double {
        isEnabled ? 1.0 : 0.6
    }

    static func shadow(isEnabled: Bool) -> AppShadowStyle {
        isEnabled ? AppShadow.cardElevated : AppShadow.none
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
    func primaryButton() -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.brandPrimary))
    }

    func successButton() -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.brandSecondary))
    }

    func destructiveButton() -> some View {
        buttonStyle(SolidButtonStyle(backgroundColor: AccessibilityColors.errorRed))
    }
}

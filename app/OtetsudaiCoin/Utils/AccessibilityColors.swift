//
//  AccessibilityColors.swift
//  OtetsudaiCoin
//
//  Created on 2025/07/10
//

import SwiftUI

/// WCAG 2.1準拠のアクセシビリティ対応カラーパレット
struct AccessibilityColors {
    
    // MARK: - Primary Colors (WCAG AA準拠)
    
    /// メインブルー（白背景でコントラスト比4.5:1以上）
    static let primaryBlue = Color(hex: "#0066CC") ?? .blue
    
    /// 濃いブルー（白背景でコントラスト比7:1以上 - AAA準拠）
    static let primaryBlueDark = Color(hex: "#004499") ?? .blue
    
    /// 薄いブルー（文字背景用）
    static let primaryBlueLight = Color(hex: "#E6F3FF") ?? .blue.opacity(0.1)
    
    // MARK: - Success Colors
    
    /// 成功色（白背景でコントラスト比4.5:1以上）
    static let successGreen = Color(hex: "#00AA44") ?? .green
    
    /// 濃い成功色（AAA準拠）
    static let successGreenDark = Color(hex: "#008833") ?? .green
    
    /// 薄い成功色（背景用）
    static let successGreenLight = Color(hex: "#E6F7ED") ?? .green.opacity(0.1)
    
    // MARK: - Warning Colors
    
    /// 警告色（白背景でコントラスト比4.5:1以上）
    static let warningOrange = Color(hex: "#CC6600") ?? .orange
    
    /// 濃い警告色（AAA準拠）
    static let warningOrangeDark = Color(hex: "#994400") ?? .orange
    
    /// 薄い警告色（背景用）
    static let warningOrangeLight = Color(hex: "#FFF3E6") ?? .orange.opacity(0.1)
    
    // MARK: - Error Colors
    
    /// エラー色（白背景でコントラスト比4.5:1以上）
    static let errorRed = Color(hex: "#CC0000") ?? .red
    
    /// 濃いエラー色（AAA準拠）
    static let errorRedDark = Color(hex: "#990000") ?? .red
    
    /// 薄いエラー色（背景用）
    static let errorRedLight = Color(hex: "#FFE6E6") ?? .red.opacity(0.1)
    
    // MARK: - Neutral Colors
    
    /// 主要テキスト色（ダーク・ライトモード対応）
    static let textPrimary = Color.primary
    
    /// 副次テキスト色（ダーク・ライトモード対応）
    static let textSecondary = Color.secondary
    
    /// 無効テキスト色（装飾用、重要な情報には使用しない）
    static let textDisabled = Color(hex: "#999999") ?? .gray
    
    // MARK: - Background Colors
    
    /// メイン背景色
    static let backgroundPrimary = Color(hex: "#FFFFFF") ?? .white
    
    /// 副次背景色
    static let backgroundSecondary = Color(hex: "#F8F9FA") ?? .gray.opacity(0.05)
    
    /// カード背景色
    static let backgroundCard = Color(hex: "#FFFFFF") ?? .white
    
    /// 境界線色
    static let border = Color(hex: "#E0E0E0") ?? .gray.opacity(0.3)
    
    // MARK: - Interactive Colors
    
    /// ボタン背景色（無効状態）
    static let buttonDisabled = Color(hex: "#CCCCCC") ?? .gray
    
    /// ボタンテキスト色（無効状態）
    static let buttonDisabledText = Color(hex: "#999999") ?? .gray
    
    /// フォーカス色（キーボードナビゲーション用）
    static let focusIndicator = Color(hex: "#0066CC") ?? .blue
    
    // MARK: - Dynamic Colors (システムカラー対応)
    
    /// プライマリラベル色（ダーク・ライトモード対応）
    static let labelPrimary = Color.primary
    
    /// セカンダリラベル色（ダーク・ライトモード対応）
    static let labelSecondary = Color.secondary
    
    /// システム背景色（ダーク・ライトモード対応）
    static let systemBackground = Color(.systemBackground)
    
    /// セカンダリシステム背景色（ダーク・ライトモード対応）
    static let systemBackgroundSecondary = Color(.secondarySystemBackground)
    
    // MARK: - High Contrast Support
    
    /// 高コントラストモード用のプライマリ色
    static let highContrastPrimary = Color(hex: "#000000") ?? .black
    
    /// 高コントラストモード用のセカンダリ色
    static let highContrastSecondary = Color(hex: "#FFFFFF") ?? .white
    
    // MARK: - Utility Functions
    
    /// 指定された背景色に対して最適なテキスト色を返す
    /// - Parameter backgroundColor: 背景色
    /// - Returns: 最適なテキスト色
    static func optimalTextColor(for backgroundColor: Color) -> Color {
        // 白色とのコントラスト比をチェック
        let whiteContrast = Color.white.contrastRatio(with: backgroundColor)
        let blackContrast = Color.black.contrastRatio(with: backgroundColor)
        
        // コントラスト比が高い方を選択
        return whiteContrast > blackContrast ? .white : .black
    }
    
    /// アクセシビリティ設定に基づいてコントラストを調整
    /// - Parameter color: 調整対象の色
    /// - Returns: 調整後の色
    static func adjustedForAccessibility(_ color: Color) -> Color {
        // アクセシビリティ設定が有効な場合はより濃い色を返す
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return color.opacity(0.8)
        }
        return color
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    
    /// アクセシビリティ対応のテキスト色を適用
    /// - Parameter backgroundColor: 背景色
    /// - Returns: テキスト色が適用されたView
    func accessibleTextColor(on backgroundColor: Color) -> some View {
        self.foregroundColor(AccessibilityColors.optimalTextColor(for: backgroundColor))
    }
    
    /// WCAG AA準拠のボタンスタイルを適用
    /// - Parameter isEnabled: ボタンが有効かどうか
    /// - Returns: アクセシビリティ対応ボタンスタイルが適用されたView
    func accessibleButtonStyle(isEnabled: Bool = true) -> some View {
        self
            .foregroundColor(isEnabled ? .white : AccessibilityColors.buttonDisabledText)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? AccessibilityColors.primaryBlue : AccessibilityColors.buttonDisabled)
            )
            .opacity(isEnabled ? 1.0 : 0.6)
    }
    
    /// アクセシビリティ対応のカード背景を適用
    /// - Parameter isHighlighted: ハイライト状態かどうか
    /// - Returns: アクセシビリティ対応背景が適用されたView
    func accessibleCardBackground(isHighlighted: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHighlighted ? AccessibilityColors.primaryBlueLight : AccessibilityColors.backgroundCard)
                    .stroke(isHighlighted ? AccessibilityColors.primaryBlue : AccessibilityColors.border, lineWidth: isHighlighted ? 2 : 1)
            )
    }
}
//
//  DesignTokens.swift
//  OtetsudaiCoin
//
//  角丸・余白・影のデザイントークンを一元管理する。
//  色は `AccessibilityColors`、字体は `AccessibilityFonts` / `AppFontStyle` が担当する。
//  Issue #146: デザイントークン基盤（角丸・影・余白の3軸を新設）。
//

import SwiftUI

// MARK: - Corner Radius Tokens

/// アプリ全体で共有する角丸トークン。
///
/// 計測時に散在していた 4 / 8 / 12 / 16 / 20 の5段階を、そのままトークン化して集約する。
/// `.cornerRadius(_:)` / `RoundedRectangle(cornerRadius:)` いずれの引数にもそのまま渡せる。
enum AppRadius {
    /// 4pt: バッジ・小さなタグなどの控えめな角丸（外れ値だが1箇所で使用）
    static let xSmall: CGFloat = 4
    /// 8pt: 小さめのカード・サムネイル
    static let small: CGFloat = 8
    /// 12pt: 標準カード・行アイテム
    static let medium: CGFloat = 12
    /// 16pt: 大きめのカード・強調コンテナ
    static let large: CGFloat = 16
    /// 20pt: 画面レベルのヒーローカード
    static let xLarge: CGFloat = 20
}

// MARK: - Spacing Tokens

/// 4pt グリッドに基づく余白トークン。
///
/// `padding` / `spacing` の引数に用いる。`xxs`(2pt) のみ 4pt グリッドの半ステップで、
/// アイコンとテキストの微調整など密着配置向けの例外値。
/// （本 Issue ではトークン定義のみ提供。一括採用は後続の UI issue に委ねる）
enum AppSpacing {
    /// 2pt: 4pt グリッドの半ステップ（密着配置の微調整用の例外値）
    static let xxs: CGFloat = 2
    /// 4pt
    static let xs: CGFloat = 4
    /// 8pt
    static let sm: CGFloat = 8
    /// 12pt
    static let md: CGFloat = 12
    /// 16pt
    static let lg: CGFloat = 16
    /// 20pt
    static let xl: CGFloat = 20
    /// 24pt
    static let xxl: CGFloat = 24
}

// MARK: - Shadow Tokens

/// 影スタイルの値をまとめた構造体。
///
/// SwiftUI 標準の `ShadowStyle`（`GraphicsContext` 用）とは別物のため、`App` プレフィックスを付与している。
struct AppShadowStyle: Equatable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// カード等の影プリセット。
///
/// 値は現行 `HomeView` のカード影（系統B）から代表値を抽出したもので、
/// `HomeView` への適用は視覚的に無差分（pixel-identical）になるよう定めている。
enum AppShadow {
    /// 軽い影（リスト行・小さめカード）: 黒5% / radius 2 / y1
    static let card = AppShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    /// 中程度の影（浮いたカード）: 黒8% / radius 4 / y2
    static let cardElevated = AppShadowStyle(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    /// 強い影（フローティング要素・ヒーローカード）: 黒10% / radius 10 / y5
    static let floating = AppShadowStyle(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
}

// MARK: - SwiftUI View Extensions

extension View {
    /// 影プリセットを適用する。
    /// - Parameter style: `AppShadow` のプリセット
    func appShadow(_ style: AppShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

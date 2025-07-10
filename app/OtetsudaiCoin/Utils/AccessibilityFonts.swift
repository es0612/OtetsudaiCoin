//
//  AccessibilityFonts.swift
//  OtetsudaiCoin
//
//  Created on 2025/07/10
//

import SwiftUI
import UIKit

/// Dynamic Typeに対応したフォント管理ユーティリティ
struct AccessibilityFonts {
    
    // MARK: - App-specific Font Styles
    
    /// アプリタイトル用フォント（大きなヘッダー）
    static var appTitle: Font {
        .largeTitle.weight(.bold)
    }
    
    /// セクションヘッダー用フォント
    static var sectionHeader: Font {
        .title2.weight(.semibold)
    }
    
    /// カード内タイトル用フォント
    static var cardTitle: Font {
        .headline.weight(.medium)
    }
    
    /// 主要情報表示用フォント（コイン数など）
    static var primaryInfo: Font {
        .title.weight(.semibold)
    }
    
    /// 副次的情報表示用フォント
    static var secondaryInfo: Font {
        .subheadline
    }
    
    /// ボタンテキスト用フォント
    static var buttonText: Font {
        .body.weight(.medium)
    }
    
    /// キャプション用フォント（小さな説明テキスト）
    static var captionText: Font {
        .caption
    }
    
    /// エラーメッセージ用フォント
    static var errorMessage: Font {
        .callout.weight(.medium)
    }
    
    // MARK: - Text Scale Helpers
    
    /// アクセシビリティ用の大きなテキストサイズが有効かチェック
    static func isAccessibilitySize() -> Bool {
        let category = UIApplication.shared.preferredContentSizeCategory
        return category.isAccessibilityCategory
    }
    
    /// サイズカテゴリに応じてスペーシングを調整
    static func adaptiveSpacing(base: CGFloat) -> CGFloat {
        let category = UIApplication.shared.preferredContentSizeCategory
        
        switch category {
        case .accessibilityMedium, .accessibilityLarge:
            return base * 1.2
        case .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return base * 1.5
        default:
            return base
        }
    }
    
    /// サイズカテゴリに応じてパディングを調整
    static func adaptivePadding(base: CGFloat) -> CGFloat {
        adaptiveSpacing(base: base)
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    
    /// アプリ固有のフォントスタイルを適用
    func appFont(_ style: AppFontStyle) -> some View {
        font(style.font)
    }
    
    /// Dynamic Typeに対応した最小行高を設定
    func accessibleLineLimit(_ limit: Int? = nil) -> some View {
        self.lineLimit(limit)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    /// アクセシビリティ用スペーシングを適用
    func accessibleSpacing() -> some View {
        self.padding(.vertical, AccessibilityFonts.adaptiveSpacing(base: 4))
    }
}

// MARK: - App Font Style Enum

enum AppFontStyle {
    case appTitle
    case sectionHeader
    case cardTitle
    case primaryInfo
    case secondaryInfo
    case buttonText
    case captionText
    case errorMessage
    
    var font: Font {
        switch self {
        case .appTitle:
            return AccessibilityFonts.appTitle
        case .sectionHeader:
            return AccessibilityFonts.sectionHeader
        case .cardTitle:
            return AccessibilityFonts.cardTitle
        case .primaryInfo:
            return AccessibilityFonts.primaryInfo
        case .secondaryInfo:
            return AccessibilityFonts.secondaryInfo
        case .buttonText:
            return AccessibilityFonts.buttonText
        case .captionText:
            return AccessibilityFonts.captionText
        case .errorMessage:
            return AccessibilityFonts.errorMessage
        }
    }
}


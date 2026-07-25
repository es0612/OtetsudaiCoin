//
//  HapticFeedback.swift
//  OtetsudaiCoin
//
//  Created on 2025/07/10
//

import UIKit
import SwiftUI

/// ハプティックフィードバック管理クラス
struct HapticFeedback {
    
    // MARK: - Impact Feedback
    
    /// 軽いインパクトフィードバック（ボタンタップなど）
    static func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// 中程度のインパクトフィードバック（選択操作など）
    static func medium() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// 強いインパクトフィードバック（重要な操作など）
    static func heavy() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    /// 柔らかいインパクトフィードバック（iOS 17以降）
    @available(iOS 17.0, *)
    static func soft() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
        impactFeedback.impactOccurred()
    }
    
    /// 硬いインパクトフィードバック（iOS 17以降）
    @available(iOS 17.0, *)
    static func rigid() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    /// 成功フィードバック
    static func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// 警告フィードバック
    static func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// エラーフィードバック
    static func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    /// 選択変更フィードバック
    static func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Application-specific Feedback
    
    /// ボタンタップ時のフィードバック
    static func buttonTap() {
        light()
    }
    
    /// 子供選択時のフィードバック
    static func childSelection() {
        medium()
    }
    
    /// タスク選択時のフィードバック
    static func taskSelection() {
        selection()
    }
    
    /// お手伝い記録完了時のフィードバック
    static func helpRecorded() {
        success()
    }
    
    /// お小遣い支払い完了時のフィードバック
    static func allowancePaid() {
        success()
    }
    
    /// エラー発生時のフィードバック
    static func errorOccurred() {
        error()
    }
    
    /// 警告表示時のフィードバック
    static func warningShown() {
        warning()
    }
    
    /// データ更新時のフィードバック
    static func dataRefreshed() {
        light()
    }
    
    /// 画面遷移時のフィードバック
    static func screenTransition() {
        light()
    }
    
    /// 長押し操作開始時のフィードバック
    static func longPressStarted() {
        if #available(iOS 17.0, *) {
            soft()
        } else {
            light()
        }
    }
    
    /// ドラッグ操作時のフィードバック
    static func dragOperation() {
        selection()
    }
    
    /// コインアニメーション開始時のフィードバック
    static func coinAnimationStarted() {
        if #available(iOS 17.0, *) {
            rigid()
        } else {
            heavy()
        }
    }
    
    // MARK: - Composite Feedback
    
    /// 成功操作の複合フィードバック（視覚 + 触覚）
    static func successfulOperation() {
        success()
        // 少し遅れて軽いインパクトを追加
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            light()
        }
    }
    
    /// 重要な操作完了の複合フィードバック
    static func importantOperationCompleted() {
        heavy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            success()
        }
    }
    
    /// エラー時の複合フィードバック
    static func errorWithEmphasis() {
        error()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            medium()
        }
    }
}

// MARK: - View Extensions

extension View {
    
    /// ボタンタップ時にハプティックフィードバックを追加
    func hapticButtonFeedback() -> some View {
        self.onTapGesture {
            HapticFeedback.buttonTap()
        }
    }
    
    /// 選択操作時にハプティックフィードバックを追加
    func hapticSelectionFeedback() -> some View {
        self.onTapGesture {
            HapticFeedback.selection()
        }
    }
    
    /// 成功操作時にハプティックフィードバックを追加
    func hapticSuccessFeedback() -> some View {
        self.onTapGesture {
            HapticFeedback.success()
        }
    }
    
    /// カスタムハプティックフィードバックを追加
    func hapticFeedback(_ feedback: @escaping () -> Void) -> some View {
        self.onTapGesture {
            feedback()
        }
    }
}

// MARK: - Button Style with Haptic Feedback

/// ハプティックフィードバック付きボタンスタイル
struct HapticButtonStyle: ButtonStyle {
    let feedbackType: HapticFeedbackType
    
    enum HapticFeedbackType {
        case light, medium, heavy, selection, success, error, warning
        
        func execute() {
            switch self {
            case .light:
                HapticFeedback.light()
            case .medium:
                HapticFeedback.medium()
            case .heavy:
                HapticFeedback.heavy()
            case .selection:
                HapticFeedback.selection()
            case .success:
                HapticFeedback.success()
            case .error:
                HapticFeedback.error()
            case .warning:
                HapticFeedback.warning()
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    feedbackType.execute()
                }
            }
    }
}

extension ButtonStyle where Self == HapticButtonStyle {
    
    /// 軽いハプティックフィードバック付きボタンスタイル
    static var hapticLight: HapticButtonStyle {
        HapticButtonStyle(feedbackType: .light)
    }
    
    /// 中程度のハプティックフィードバック付きボタンスタイル
    static var hapticMedium: HapticButtonStyle {
        HapticButtonStyle(feedbackType: .medium)
    }
    
    /// 強いハプティックフィードバック付きボタンスタイル
    static var hapticHeavy: HapticButtonStyle {
        HapticButtonStyle(feedbackType: .heavy)
    }
    
    /// 選択フィードバック付きボタンスタイル
    static var hapticSelection: HapticButtonStyle {
        HapticButtonStyle(feedbackType: .selection)
    }
    
    /// 成功フィードバック付きボタンスタイル
    static var hapticSuccess: HapticButtonStyle {
        HapticButtonStyle(feedbackType: .success)
    }
}
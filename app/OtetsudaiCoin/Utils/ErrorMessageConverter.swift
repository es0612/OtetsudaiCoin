//
//  ErrorMessageConverter.swift
//  OtetsudaiCoin
//
//  Created on 2025/07/10
//

import Foundation

/// エラーメッセージをユーザーフレンドリーな形に変換するクラス
struct ErrorMessageConverter {
    
    /// 技術的なエラーメッセージをユーザーにとって理解しやすい形に変換
    /// - Parameter error: 変換対象のエラー
    /// - Returns: ユーザーフレンドリーなエラーメッセージ
    static func convertToUserFriendlyMessage(_ error: Error) -> String {
        // PersistenceErrorの場合は、既に日本語化されているのでそのまま使用
        if let persistenceError = error as? PersistenceError {
            return persistenceError.localizedDescription
        }
        
        // Core Dataエラーの変換
        if error.localizedDescription.contains("NSCocoaErrorDomain") {
            return convertCoreDataError(error)
        }
        
        // ネットワークエラーの変換
        if error.localizedDescription.contains("NSURLErrorDomain") {
            return convertNetworkError(error)
        }
        
        // ファイルシステムエラーの変換
        if error.localizedDescription.contains("NSPOSIXErrorDomain") {
            return convertFileSystemError(error)
        }
        
        // 一般的なエラーパターンの変換
        return convertCommonError(error)
    }
    
    // MARK: - Private Methods
    
    private static func convertCoreDataError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("disk") || description.contains("space") {
            return String(localized: "ストレージ容量が不足しています。デバイスの空き容量を確保してください。")
        }

        if description.contains("permission") || description.contains("access") {
            return String(localized: "データベースへのアクセスが拒否されました。アプリを再起動してください。")
        }

        if description.contains("corrupt") || description.contains("invalid") {
            return String(localized: "データベースに問題が発生しました。アプリを再起動してください。")
        }

        if description.contains("timeout") {
            return String(localized: "処理に時間がかかりすぎています。しばらく待ってから再度お試しください。")
        }

        return String(localized: "データベースエラーが発生しました。アプリを再起動してください。")
    }

    private static func convertNetworkError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("not connected") || description.contains("offline") {
            return String(localized: "インターネット接続を確認してください。")
        }

        if description.contains("timeout") {
            return String(localized: "接続がタイムアウトしました。しばらく待ってから再度お試しください。")
        }

        if description.contains("server") {
            return String(localized: "サーバーに接続できません。しばらく待ってから再度お試しください。")
        }

        return String(localized: "ネットワークエラーが発生しました。接続を確認してください。")
    }

    private static func convertFileSystemError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("no space") || description.contains("disk full") {
            return String(localized: "ストレージ容量が不足しています。デバイスの空き容量を確保してください。")
        }

        if description.contains("permission denied") {
            return String(localized: "ファイルへのアクセスが拒否されました。アプリを再起動してください。")
        }

        if description.contains("file not found") {
            return String(localized: "必要なファイルが見つかりません。アプリを再インストールしてください。")
        }

        return String(localized: "ファイルシステムエラーが発生しました。アプリを再起動してください。")
    }

    private static func convertCommonError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        // よくあるエラーパターンの変換
        if description.contains("invalid") || description.contains("format") {
            return String(localized: "入力データに問題があります。もう一度お試しください。")
        }

        if description.contains("cancelled") {
            return String(localized: "処理がキャンセルされました。")
        }

        if description.contains("memory") {
            return String(localized: "メモリが不足しています。他のアプリを終了してから再度お試しください。")
        }

        if description.contains("duplicate") {
            return String(localized: "同じデータが既に存在します。")
        }

        // フォールバック：技術的な内容を含む場合は一般的なメッセージに変換
        if containsTechnicalTerms(description) {
            return String(localized: "予期しないエラーが発生しました。アプリを再起動してください。")
        }

        // 既に日本語で分かりやすい場合はそのまま使用
        return error.localizedDescription
    }
    
    private static func containsTechnicalTerms(_ description: String) -> Bool {
        let technicalTerms = [
            "nserror", "code", "domain", "userinfo", "exception",
            "null", "undefined", "runtime", "assertion", "fatal"
        ]
        
        return technicalTerms.contains { description.contains($0) }
    }
}

// MARK: - ViewModelへの拡張

extension BaseViewModel {
    /// エラーメッセージをユーザーフレンドリーな形で設定
    /// - Parameter error: 発生したエラー
    @MainActor
    func setUserFriendlyError(_ error: Error) {
        let friendlyMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
        setError(friendlyMessage)
    }
}
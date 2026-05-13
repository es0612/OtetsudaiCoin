import Foundation

/// App Store のレビュー画面に直接遷移するためのヘルパー。
///
/// `SKStoreReviewController.requestReview` / `AppStore.requestReview` は本番ビルドでのみ
/// ダイアログが表示され、TestFlight / Debug ビルドでは抑制される。
/// 「押しても何も起きない」を避けるためのフォールバックとして、`itms-apps://` スキームで
/// App Store のレビュー画面に直接遷移する URL を提供する。
///
/// `APP_STORE_APP_ID` は Build Settings 経由で Info.plist に注入される。
/// 未設定（空文字）や非数字の値の場合は `writeReviewURL` が nil を返し、
/// UI 側でボタンを非表示にする運用を想定。
enum AppStoreReviewer {
    static var appStoreAppID: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "APP_STORE_APP_ID") as? String ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var writeReviewURL: URL? {
        writeReviewURL(for: appStoreAppID)
    }

    static func writeReviewURL(for appID: String) -> URL? {
        let trimmed = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.allSatisfy(\.isNumber)
        else { return nil }
        return URL(string: "itms-apps://itunes.apple.com/app/id\(trimmed)?action=write-review")
    }
}

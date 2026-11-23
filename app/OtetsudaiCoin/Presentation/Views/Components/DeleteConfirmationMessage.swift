import Foundation

/// 子ども・お手伝いの削除確認ダイアログの本文 (#310 (a))。
///
/// 削除するとその子ども・お手伝いの過去の記録も消える (Core Data の Cascade) ため、
/// 記録が 1 件以上あるときは件数を添えて知らせる。0 件や件数を数えられなかったときは今までの文面のまま。
enum DeleteConfirmationMessage {
    /// - Parameters:
    ///   - recordCount: 一緒に消える記録の件数。数えられなかったときは nil。
    ///   - showsDisableHint: 記録を残したまま記録の画面から外せる「無効にする」を案内するか (有効なお手伝いのみ)。
    ///   - bundle: テストで言語を固定するためのもの。通常は省略する。
    static func make(
        name: String,
        recordCount: Int?,
        showsDisableHint: Bool = false,
        bundle: Bundle = .main,
        locale: Locale = .current
    ) -> String {
        guard let recordCount, recordCount > 0 else {
            return String(localized: "\(name)を削除しますか？この操作は取り消せません。", bundle: bundle, locale: locale)
        }

        // 件数の文は en の単数・複数 (1 record / 2 records) を catalog の plural で分けるため、
        // 名前と別のキーにして interpolation で引く (String(format:) だと常に複数形になる)
        let recordsWarning = String(localized: "これまでの記録 \(recordCount) 件も消えます。", bundle: bundle, locale: locale)
        let message = String(
            localized: "\(name)を削除しますか？\(recordsWarning)この操作は取り消せません。",
            bundle: bundle,
            locale: locale
        )
        guard showsDisableHint else { return message }

        let hint = String(
            localized: "記録の画面から外すだけなら「無効にする」を使ってください。記録は残ります。",
            bundle: bundle,
            locale: locale
        )
        return message + "\n" + hint
    }
}

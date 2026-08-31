import Foundation

/// 記録時刻の locale 対応フォーマット helper (#206)。
///
/// 旧実装は `HelpHistoryView` の static メンバーで、独立 struct の `HelpRecordRow` が
/// `HelpHistoryView.timeString(...)` を呼ぶ名前空間依存があった (PR #204 bot 指摘)。
/// `HelpRecordRow` を別画面で再利用しても View への依存を引き連れないよう独立させる。
enum TimeStringFormatter {

    /// 記録時刻 formatter の locale 別 cache (#201)。
    /// 旧実装は呼び出し (= HelpRecordRow の行 render) ごとに DateFormatter を生成しており、
    /// 長い履歴リストのスクロールで全可視行分の生成+設定コストが発生していた。
    /// View body (= MainActor) からしか呼ばれないため @MainActor で隔離し、
    /// 素の static var の data race を避ける。
    @MainActor
    private static var timeFormatterCache: [String: DateFormatter] = [:]

    /// locale に対応する時刻 formatter を返す (cache 済みなら再利用)。
    @MainActor
    static func timeFormatter(locale: Locale) -> DateFormatter {
        if let cached = timeFormatterCache[locale.identifier] {
            return cached
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = locale
        timeFormatterCache[locale.identifier] = formatter
        return formatter
    }

    /// 記録時刻を locale に応じて生成する (#155 コメント報告の i18n 漏れ対応)。
    ///
    /// 旧実装は `HelpRecordRow` 内の private func で ja_JP 固定になっており、
    /// en ロケールでも 24 時間表記が強制されていた。`.short` スタイルは
    /// ja で「9:05」(現行と同一)、en で「9:05 AM」になる。
    @MainActor
    static func timeString(from date: Date, locale: Locale) -> String {
        timeFormatter(locale: locale).string(from: date)
    }
}

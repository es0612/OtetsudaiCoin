import XCTest
@testable import OtetsudaiCoin

/// HelpHistoryView の日付・時刻フォーマット helper のテスト (#155 コメント報告の i18n 漏れ)。
///
/// - 日付 fixture は固定絶対日付 (2026-07-15 = 月中日) を使い、実行日非依存にする (#112/#114/#115 の flake 対策)。
/// - locale は明示的に ja_JP / en_US を渡し、実行環境 locale に依存しない。
/// - View 本体の traverse は ViewInspector の既知制約があるため行わず、static helper を直接検証する。
final class HelpHistoryViewTests: XCTestCase {

    /// 2026-07-15 (水) 09:05 を gregorian で固定生成する。
    private func fixedDate(hour: Int = 9, minute: Int = 5) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 15
        components.hour = hour
        components.minute = minute
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components)!
    }

    // MARK: - dayGroupLabel (履歴の日付グループ見出し)

    /// ja では現行の「7月15日 (水)」とほぼ同等 (テンプレート化で括弧前スペースのみ消える) であること (非退行)。
    func testDayGroupLabelJapaneseLocaleKeepsCurrentStyle() {
        let label = HelpHistoryView.dayGroupLabel(
            from: fixedDate(), locale: Locale(identifier: "ja_JP")
        )
        XCTAssertEqual(label, "7月15日(水)", "rendered: \(label)")
    }

    /// en では「Wed, Jul 15」相当のローカライズ表記になること (旧実装は ja_JP 固定で「7月15日 (水)」が出る実バグ)。
    func testDayGroupLabelEnglishLocaleUsesLocalizedTemplate() {
        let label = HelpHistoryView.dayGroupLabel(
            from: fixedDate(), locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(label, "Wed, Jul 15", "rendered: \(label)")
        XCTAssertFalse(label.contains("月"), "en locale に日本語表記が混入: \(label)")
    }

    // MARK: - timeString (記録時刻)

    /// ja では現行の「9:05」と同一であること (非退行)。
    func testTimeStringJapaneseLocaleKeepsCurrentStyle() {
        let time = HelpHistoryView.timeString(
            from: fixedDate(), locale: Locale(identifier: "ja_JP")
        )
        XCTAssertEqual(time, "9:05", "rendered: \(time)")
    }

    /// en では 12 時間表記 + AM/PM になること。
    /// AM 前の空白は ICU バージョンにより U+202F (narrow no-break space) になるため、
    /// 空白文字そのものは assert せず prefix + AM 含有で判定する。
    func testTimeStringEnglishLocaleUsesLocalizedStyle() {
        let time = HelpHistoryView.timeString(
            from: fixedDate(), locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(time.hasPrefix("9:05"), "rendered: \(time)")
        XCTAssertTrue(time.contains("AM"), "rendered: \(time)")
    }
}

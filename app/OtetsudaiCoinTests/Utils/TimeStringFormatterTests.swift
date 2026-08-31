import XCTest
@testable import OtetsudaiCoin

/// TimeStringFormatter (#206 で HelpHistoryView から移設) のテスト。
///
/// - 日付 fixture は固定絶対日付 (2026-07-15 = 月中日) を使い、実行日非依存にする (#112/#114/#115 の flake 対策)。
/// - locale は明示的に ja_JP / en_US を渡し、実行環境 locale に依存しない。
@MainActor
final class TimeStringFormatterTests: XCTestCase {

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

    /// ja では現行の「9:05」と同一であること (非退行)。
    func testTimeStringJapaneseLocaleKeepsCurrentStyle() {
        let time = TimeStringFormatter.timeString(
            from: fixedDate(), locale: Locale(identifier: "ja_JP")
        )
        XCTAssertEqual(time, "9:05", "rendered: \(time)")
    }

    /// en では 12 時間表記 + AM/PM になること。
    /// AM 前の空白は ICU バージョンにより U+202F (narrow no-break space) になるため、
    /// 空白文字そのものは assert せず prefix + AM 含有で判定する。
    func testTimeStringEnglishLocaleUsesLocalizedStyle() {
        let time = TimeStringFormatter.timeString(
            from: fixedDate(), locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(time.hasPrefix("9:05"), "rendered: \(time)")
        XCTAssertTrue(time.contains("AM"), "rendered: \(time)")
    }

    /// 同一 locale では formatter instance が再利用されること (行 render ごとの生成コスト解消)。
    func testTimeFormatterIsCachedPerLocale() {
        let ja1 = TimeStringFormatter.timeFormatter(locale: Locale(identifier: "ja_JP"))
        let ja2 = TimeStringFormatter.timeFormatter(locale: Locale(identifier: "ja_JP"))
        XCTAssertTrue(ja1 === ja2, "同一 locale で formatter が再生成されている")

        let en = TimeStringFormatter.timeFormatter(locale: Locale(identifier: "en_US"))
        XCTAssertFalse(ja1 === en, "locale が異なるのに同一 formatter が返っている")
    }
}

import XCTest
@testable import OtetsudaiCoin

/// 子ども・お手伝いの削除確認ダイアログの本文 (#310 (a))。
/// 言語は lproj の bundle と locale を渡して固定する (テストの実行言語に依存させない)。
final class DeleteConfirmationMessageTests: XCTestCase {

    private func bundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: language, ofType: "lproj"),
            "\(language).lproj がアプリの bundle にあるべき"
        )
        return try XCTUnwrap(Bundle(path: path))
    }

    private func message(
        name: String,
        recordCount: Int?,
        showsDisableHint: Bool = false,
        language: String
    ) throws -> String {
        DeleteConfirmationMessage.make(
            name: name,
            recordCount: recordCount,
            showsDisableHint: showsDisableHint,
            bundle: try bundle(language),
            locale: Locale(identifier: language)
        )
    }

    // MARK: - 記録が 0 件 / 件数が分からない: 今までの文面

    /// SettingsView の旧実装 `name ?? "" + "を削除しますか？…"` は名前だけを出していた。
    func test_noRecords_ja_includesQuestionNotOnlyName() throws {
        let text = try message(name: "太郎", recordCount: 0, language: "ja")
        XCTAssertEqual(text, "太郎を削除しますか？この操作は取り消せません。")
    }

    func test_noRecords_en_usesExistingTranslation() throws {
        let text = try message(name: "Taro", recordCount: 0, language: "en")
        XCTAssertEqual(text, "Delete Taro? This action cannot be undone.")
    }

    /// 件数を数えられなかったとき (nil) は、0 件と同じ今までの文面にする。
    func test_unknownCount_fallsBackToExistingText() throws {
        let text = try message(name: "太郎", recordCount: nil, language: "ja")
        XCTAssertEqual(text, "太郎を削除しますか？この操作は取り消せません。")
    }

    /// 0 件のお手伝いには「無効にする」の案内を出さない (消える記録が無いので)。
    func test_noRecords_task_hasNoDisableHint() throws {
        let text = try message(name: "お皿洗い", recordCount: 0, showsDisableHint: true, language: "ja")
        XCTAssertEqual(text, "お皿洗いを削除しますか？この操作は取り消せません。")
    }

    // MARK: - 記録が 1 件以上: 件数の警告

    func test_withRecords_child_ja() throws {
        let text = try message(name: "太郎", recordCount: 3, language: "ja")
        XCTAssertEqual(text, "太郎を削除しますか？これまでの記録 3 件も消えます。この操作は取り消せません。")
    }

    /// en の単数形 (one)。`String(format:)` で組むと plural が効かず "1 past records" になる。
    func test_withOneRecord_en_usesSingular() throws {
        let text = try message(name: "Taro", recordCount: 1, language: "en")
        XCTAssertEqual(text, "Delete Taro? 1 past record will also be deleted. This action cannot be undone.")
    }

    func test_withTwoRecords_en_usesPlural() throws {
        let text = try message(name: "Taro", recordCount: 2, language: "en")
        XCTAssertEqual(text, "Delete Taro? 2 past records will also be deleted. This action cannot be undone.")
    }

    func test_withRecords_task_ja_appendsDisableHint() throws {
        let text = try message(name: "お皿洗い", recordCount: 2, showsDisableHint: true, language: "ja")
        XCTAssertEqual(
            text,
            "お皿洗いを削除しますか？これまでの記録 2 件も消えます。この操作は取り消せません。\n"
                + "記録の画面から外すだけなら「無効にする」を使ってください。記録は残ります。"
        )
    }

    /// 「無効にする」の en 訳は catalog の "Disable" に揃える。
    func test_withRecords_task_en_appendsDisableHint() throws {
        let text = try message(name: "Dishes", recordCount: 1, showsDisableHint: true, language: "en")
        XCTAssertEqual(
            text,
            "Delete Dishes? 1 past record will also be deleted. This action cannot be undone.\n"
                + "To just hide it from the Record screen, use “Disable”. Its records are kept."
        )
    }
}

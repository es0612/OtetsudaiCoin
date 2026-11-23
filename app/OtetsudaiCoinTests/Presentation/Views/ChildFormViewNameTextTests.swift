import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// 子どもフォームのプレビュー名が、空なら翻訳され、入力された名前はそのまま出ること (#308)。
/// 三項演算子で `Text(name.isEmpty ? "お名前未入力" : name)` と書くと `String` に推論され翻訳を引かなかった。
final class ChildFormViewNameTextTests: XCTestCase {

    private func rendered(_ name: String, locale identifier: String) throws -> String {
        try ChildFormView.previewNameText(for: name).inspect().text().string(locale: Locale(identifier: identifier))
    }

    func test_emptyName_resolvesEnglish() throws {
        XCTAssertEqual(try rendered("", locale: "en"), "Name not entered")
    }

    func test_emptyName_keepsJapanese() throws {
        XCTAssertEqual(try rendered("", locale: "ja"), "お名前未入力")
    }

    func test_name_isVerbatim_evenIfKey() throws {
        // catalog のキー「ホーム画面」(en: Home Screen) と同じ名前でも翻訳されない
        XCTAssertEqual(try rendered("ホーム画面", locale: "en"), "ホーム画面")
    }
}

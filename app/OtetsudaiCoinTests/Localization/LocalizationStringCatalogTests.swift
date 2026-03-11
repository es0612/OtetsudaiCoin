import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// String Catalog (.xcstrings) ファイルの整合性を検証するテスト
final class LocalizationStringCatalogTests: XCTestCase {

    private var catalogData: [String: Any]!
    private var strings: [String: Any]!

    override func setUp() {
        super.setUp()

        // .xcstrings はビルド時にコンパイルされるため、ソースファイルから直接読み込む
        let testFileURL = URL(fileURLWithPath: #filePath)
        let xcstringsURL = testFileURL
            .deletingLastPathComponent() // Localization/
            .deletingLastPathComponent() // OtetsudaiCoinTests/
            .deletingLastPathComponent() // app/
            .appendingPathComponent("OtetsudaiCoin")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        guard let data = try? Data(contentsOf: xcstringsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Localizable.xcstrings の JSON パースに失敗しました: \(xcstringsURL.path)")
            return
        }

        catalogData = json
        strings = json["strings"] as? [String: Any] ?? [:]
    }

    override func tearDown() {
        catalogData = nil
        strings = nil
        super.tearDown()
    }

    // MARK: - String Catalog 構造テスト

    func testSourceLanguageIsJapanese() {
        // Given: String Catalog ファイルが読み込まれている
        // When: sourceLanguage を取得する
        let sourceLanguage = catalogData["sourceLanguage"] as? String

        // Then: ソース言語が日本語であること
        XCTAssertEqual(sourceLanguage, "ja", "sourceLanguage は 'ja' であるべき")
    }

    func testVersionExists() {
        // Given: String Catalog ファイルが読み込まれている
        // When: version を取得する
        let version = catalogData["version"] as? String

        // Then: バージョンが存在すること
        XCTAssertNotNil(version, "version が設定されているべき")
    }

    func testStringsEntryExists() {
        // Given: String Catalog ファイルが読み込まれている
        // Then: strings エントリが空でないこと
        XCTAssertFalse(strings.isEmpty, "strings エントリが空であってはならない")
    }

    // MARK: - ViewModel エラーメッセージのキー存在テスト

    func testViewModelErrorMessageKeysExist() {
        let expectedErrorKeys = [
            "お子様を選択してください",
            "お手伝いタスクを選択してください",
            "入力データが無効です",
            "同じ名前の子供が既に登録されています",
            "削除対象の子供が見つかりません",
            "子供が選択されていません",
            "タスク名を入力してください",
            "コイン単価は1以上で入力してください",
            "同じ名前のタスクが既に存在します",
        ]

        for key in expectedErrorKeys {
            XCTAssertNotNil(
                strings[key],
                "エラーメッセージキー '\(key)' が String Catalog に存在すべき"
            )
        }
    }

    // MARK: - ViewModel 成功メッセージのキー存在テスト

    func testViewModelSuccessMessageKeysExist() {
        let expectedSuccessKeys = [
            "お手伝いを記録しました！",
            "記録を更新しました",
            "記録を削除しました",
            "タスクを追加しました",
            "タスクを更新しました",
            "タスクを削除しました",
        ]

        for key in expectedSuccessKeys {
            XCTAssertNotNil(
                strings[key],
                "成功メッセージキー '\(key)' が String Catalog に存在すべき"
            )
        }
    }

    // MARK: - ErrorMessageConverter のキー存在テスト

    func testErrorMessageConverterKeysExist() {
        let expectedKeys = [
            "ストレージ容量が不足しています。デバイスの空き容量を確保してください。",
            "データベースへのアクセスが拒否されました。アプリを再起動してください。",
            "データベースに問題が発生しました。アプリを再起動してください。",
            "処理に時間がかかりすぎています。しばらく待ってから再度お試しください。",
            "データベースエラーが発生しました。アプリを再起動してください。",
            "インターネット接続を確認してください。",
            "接続がタイムアウトしました。しばらく待ってから再度お試しください。",
            "サーバーに接続できません。しばらく待ってから再度お試しください。",
            "ネットワークエラーが発生しました。接続を確認してください。",
            "ファイルへのアクセスが拒否されました。アプリを再起動してください。",
            "必要なファイルが見つかりません。アプリを再インストールしてください。",
            "ファイルシステムエラーが発生しました。アプリを再起動してください。",
            "入力データに問題があります。もう一度お試しください。",
            "処理がキャンセルされました。",
            "メモリが不足しています。他のアプリを終了してから再度お試しください。",
            "同じデータが既に存在します。",
            "予期しないエラーが発生しました。アプリを再起動してください。",
        ]

        for key in expectedKeys {
            XCTAssertNotNil(
                strings[key],
                "ErrorMessageConverter キー '\(key)' が String Catalog に存在すべき"
            )
        }
    }

    // MARK: - PersistenceError のキー存在テスト

    func testPersistenceErrorKeysExist() {
        // PersistenceError は補間を含むため、フォーマット指定子形式のキーを検証
        let keyPatterns = [
            "データベースの読み込みに失敗しました",
            "データの保存に失敗しました",
        ]

        for pattern in keyPatterns {
            let found = strings.keys.contains { key in
                key.contains(pattern)
            }
            XCTAssertTrue(
                found,
                "PersistenceError パターン '\(pattern)' を含むキーが String Catalog に存在すべき"
            )
        }
    }

    // MARK: - NetworkStatusIndicator のキー存在テスト

    func testNetworkStatusIndicatorKeysExist() {
        let expectedKeys = [
            "オフライン",
            "モバイル",
            "接続中",
        ]

        for key in expectedKeys {
            XCTAssertNotNil(
                strings[key],
                "ネットワークステータスキー '\(key)' が String Catalog に存在すべき"
            )
        }
    }

    // MARK: - MonthlyRecord のキー存在テスト

    func testMonthlyRecordPaymentStatusKeysExist() {
        let expectedKeys = [
            "未支払い",
            "一部支払い済み",
            "支払い済み",
        ]

        for key in expectedKeys {
            XCTAssertNotNil(
                strings[key],
                "支払いステータスキー '\(key)' が String Catalog に存在すべき"
            )
        }
    }

    // MARK: - 英語翻訳の存在テスト

    func testAllKeysHaveEnglishTranslation() {
        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else {
                XCTFail("キー '\(key)' に localizations エントリがありません")
                continue
            }

            guard let enLocalization = localizations["en"] as? [String: Any] else {
                XCTFail("キー '\(key)' に英語翻訳がありません")
                continue
            }

            guard let stringUnit = enLocalization["stringUnit"] as? [String: Any] else {
                // substitutions を含む複合キーの場合は stringUnit ではなく別形式の可能性がある
                continue
            }

            let translatedValue = stringUnit["value"] as? String ?? ""
            XCTAssertFalse(
                translatedValue.isEmpty,
                "キー '\(key)' の英語翻訳が空であってはならない"
            )
        }
    }

    func testEnglishTranslationsAreMarkedAsTranslated() {
        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let enLocalization = localizations["en"] as? [String: Any],
                  let stringUnit = enLocalization["stringUnit"] as? [String: Any] else {
                continue
            }

            let state = stringUnit["state"] as? String
            XCTAssertEqual(
                state, "translated",
                "キー '\(key)' の英語翻訳の state が 'translated' であるべき"
            )
        }
    }

    // MARK: - ViewInspectorロケール整合テスト

    /// ViewInspectorのデフォルトロケールは英語のため、String Catalogに存在する
    /// 日本語キーは `locale: Locale(identifier: "ja")` を指定しないとマッチしない。
    /// このテストは、ロケール指定なしで検索が失敗し、ja指定で成功することを検証する。
    @MainActor
    func testViewInspectorRequiresJapaneseLocaleForLocalizedKeys() throws {
        // "コイン" はString Catalogに英語翻訳 "Coins" がある
        let view = CoinAnimationView(
            isVisible: .constant(true),
            coinValue: 100,
            themeColor: "#FF5733"
        )

        // デフォルトロケール(en)では日本語キーがマッチしない
        XCTAssertThrowsError(
            try view.inspect().find(text: "コイン"),
            "デフォルトロケール(en)では日本語キー 'コイン' は 'Coins' に解決されるため検索が失敗すべき"
        )

        // jaロケール指定で日本語キーがマッチする
        XCTAssertNoThrow(
            try view.inspect().find(text: "コイン", locale: Locale(identifier: "ja")),
            "jaロケール指定なら日本語キー 'コイン' で検索が成功すべき"
        )
    }

    // MARK: - 翻訳品質テスト

    func testEnglishTranslationsAreNotJapanese() {
        let japaneseCharacterSet = CharacterSet(
            charactersIn: "\u{3040}"..."\u{309F}" // ひらがな
        ).union(CharacterSet(
            charactersIn: "\u{30A0}"..."\u{30FF}" // カタカナ
        )).union(CharacterSet(
            charactersIn: "\u{4E00}"..."\u{9FFF}" // CJK統合漢字
        ))

        for (key, value) in strings {
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let enLocalization = localizations["en"] as? [String: Any],
                  let stringUnit = enLocalization["stringUnit"] as? [String: Any],
                  let translatedValue = stringUnit["value"] as? String else {
                continue
            }

            // フォーマット指定子（%@, %lld 等）を除外した文字列で判定
            let cleanedValue = translatedValue
                .replacingOccurrences(of: "%@", with: "")
                .replacingOccurrences(of: "%lld", with: "")
                .replacingOccurrences(of: "%1$@", with: "")
                .replacingOccurrences(of: "%2$lld", with: "")
                .trimmingCharacters(in: .whitespaces)

            guard !cleanedValue.isEmpty else { continue }

            let containsJapanese = cleanedValue.unicodeScalars.contains { scalar in
                japaneseCharacterSet.contains(scalar)
            }

            XCTAssertFalse(
                containsJapanese,
                "キー '\(key)' の英語翻訳 '\(translatedValue)' に日本語文字が含まれています"
            )
        }
    }
}

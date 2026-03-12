import XCTest

/// InfoPlist.strings ファイルによるアプリ表示名ローカライズの整合性を検証するテスト
///
/// CFBundleDisplayName が各言語の InfoPlist.strings に正しく定義されていることを確認する。
/// - 日本語: 「おてつだいコイン」
/// - 英語: 「OtetsudaiCoin」
final class InfoPlistLocalizationTests: XCTestCase {

    private var jaStringsURL: URL!
    private var enStringsURL: URL!

    override func setUp() {
        super.setUp()

        let testFileURL = URL(fileURLWithPath: #filePath)
        let appSourceRoot = testFileURL
            .deletingLastPathComponent() // Localization/
            .deletingLastPathComponent() // OtetsudaiCoinTests/
            .deletingLastPathComponent() // app/
            .appendingPathComponent("OtetsudaiCoin")

        jaStringsURL = appSourceRoot
            .appendingPathComponent("ja.lproj")
            .appendingPathComponent("InfoPlist.strings")

        enStringsURL = appSourceRoot
            .appendingPathComponent("en.lproj")
            .appendingPathComponent("InfoPlist.strings")
    }

    override func tearDown() {
        jaStringsURL = nil
        enStringsURL = nil
        super.tearDown()
    }

    // MARK: - ファイル存在テスト

    func testJapaneseInfoPlistStringsFileExists() {
        // Given: 日本語ローカライズ用の InfoPlist.strings パス
        // When: ファイルの存在を確認する
        let exists = FileManager.default.fileExists(atPath: jaStringsURL.path)

        // Then: ファイルが存在すること
        XCTAssertTrue(exists, "ja.lproj/InfoPlist.strings が存在すべき")
    }

    func testEnglishInfoPlistStringsFileExists() {
        // Given: 英語ローカライズ用の InfoPlist.strings パス
        // When: ファイルの存在を確認する
        let exists = FileManager.default.fileExists(atPath: enStringsURL.path)

        // Then: ファイルが存在すること
        XCTAssertTrue(exists, "en.lproj/InfoPlist.strings が存在すべき")
    }

    // MARK: - 日本語ローカライズテスト

    func testJapaneseDisplayNameIsCorrect() throws {
        // Given: 日本語 InfoPlist.strings の内容
        let content = try loadStringsFile(at: jaStringsURL)

        // When: CFBundleDisplayName の値を取得する
        let displayName = content["CFBundleDisplayName"] as? String

        // Then: 日本語のアプリ名であること
        XCTAssertEqual(displayName, "おてつだいコイン", "日本語の CFBundleDisplayName は 'おてつだいコイン' であるべき")
    }

    func testJapaneseStringsFileContainsCFBundleDisplayName() throws {
        // Given: 日本語 InfoPlist.strings の内容
        let content = try loadStringsFile(at: jaStringsURL)

        // When: CFBundleDisplayName キーの存在を確認する
        // Then: キーが定義されていること
        XCTAssertNotNil(content["CFBundleDisplayName"], "日本語 InfoPlist.strings に CFBundleDisplayName が定義されているべき")
    }

    // MARK: - 英語ローカライズテスト

    func testEnglishDisplayNameIsCorrect() throws {
        // Given: 英語 InfoPlist.strings の内容
        let content = try loadStringsFile(at: enStringsURL)

        // When: CFBundleDisplayName の値を取得する
        let displayName = content["CFBundleDisplayName"] as? String

        // Then: 英語のアプリ名であること
        XCTAssertEqual(displayName, "OtetsudaiCoin", "英語の CFBundleDisplayName は 'OtetsudaiCoin' であるべき")
    }

    func testEnglishStringsFileContainsCFBundleDisplayName() throws {
        // Given: 英語 InfoPlist.strings の内容
        let content = try loadStringsFile(at: enStringsURL)

        // When: CFBundleDisplayName キーの存在を確認する
        // Then: キーが定義されていること
        XCTAssertNotNil(content["CFBundleDisplayName"], "英語 InfoPlist.strings に CFBundleDisplayName が定義されているべき")
    }

    // MARK: - フォーマット整合性テスト

    func testJapaneseStringsFileIsParseable() {
        // Given: 日本語 InfoPlist.strings のパス
        // When: .strings フォーマットとしてパースを試みる
        // Then: パースエラーが発生しないこと
        XCTAssertNoThrow(try loadStringsFile(at: jaStringsURL), "ja.lproj/InfoPlist.strings は有効な .strings フォーマットであるべき")
    }

    func testEnglishStringsFileIsParseable() {
        // Given: 英語 InfoPlist.strings のパス
        // When: .strings フォーマットとしてパースを試みる
        // Then: パースエラーが発生しないこと
        XCTAssertNoThrow(try loadStringsFile(at: enStringsURL), "en.lproj/InfoPlist.strings は有効な .strings フォーマットであるべき")
    }

    // MARK: - 言語間整合性テスト

    func testBothLocalesDefineSameKeys() throws {
        // Given: 両言語の InfoPlist.strings
        let jaContent = try loadStringsFile(at: jaStringsURL)
        let enContent = try loadStringsFile(at: enStringsURL)

        // When: 両ファイルのキーセットを比較する
        let jaKeys = Set(jaContent.allKeys.compactMap { $0 as? String })
        let enKeys = Set(enContent.allKeys.compactMap { $0 as? String })

        // Then: 同じキーが定義されていること
        XCTAssertEqual(jaKeys, enKeys, "日本語と英語の InfoPlist.strings は同じキーセットを持つべき")
    }

    func testJapaneseDisplayNameContainsJapaneseCharacters() throws {
        // Given: 日本語のアプリ表示名
        let content = try loadStringsFile(at: jaStringsURL)
        let displayName = try XCTUnwrap(content["CFBundleDisplayName"] as? String)

        // When: 日本語文字（ひらがな・カタカナ）の存在を確認する
        let hiraganaRange = "\u{3040}"..."\u{309F}"
        let katakanaRange = "\u{30A0}"..."\u{30FF}"
        let containsJapanese = displayName.unicodeScalars.contains { scalar in
            hiraganaRange.contains(String(scalar)) || katakanaRange.contains(String(scalar))
        }

        // Then: 日本語文字を含むこと
        XCTAssertTrue(containsJapanese, "日本語のアプリ表示名は日本語文字を含むべき")
    }

    func testEnglishDisplayNameContainsOnlyASCII() throws {
        // Given: 英語のアプリ表示名
        let content = try loadStringsFile(at: enStringsURL)
        let displayName = try XCTUnwrap(content["CFBundleDisplayName"] as? String)

        // When: ASCII文字のみで構成されているか確認する
        let isASCIIOnly = displayName.allSatisfy { $0.isASCII }

        // Then: ASCII文字のみであること
        XCTAssertTrue(isASCIIOnly, "英語のアプリ表示名は ASCII 文字のみであるべき")
    }

    // MARK: - Private

    private func loadStringsFile(at url: URL) throws -> NSDictionary {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "InfoPlistLocalizationTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "ファイルが存在しません: \(url.path)"]
            )
        }

        guard let dict = NSDictionary(contentsOf: url) else {
            throw NSError(
                domain: "InfoPlistLocalizationTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: ".strings ファイルのパースに失敗しました: \(url.path)"]
            )
        }

        return dict
    }
}

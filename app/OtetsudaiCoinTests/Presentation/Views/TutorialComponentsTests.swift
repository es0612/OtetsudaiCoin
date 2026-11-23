import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// チュートリアルの 4 部品が、表示言語に合わせて翻訳されること (#308)。
/// `String` で受けて `Text(title)` と書くと翻訳を引かず、en でも日本語のまま出ていた。
final class TutorialComponentsTests: XCTestCase {

    private func renderedTexts<V: View>(_ view: V, locale identifier: String) throws -> [String] {
        try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string(locale: Locale(identifier: identifier)) }
    }

    func test_featureRow_resolvesEnglish() throws {
        let texts = try renderedTexts(FeatureRow(icon: "person.badge.plus", title: "お子様を登録", description: "名前や好きな色を設定"), locale: "en")

        XCTAssertTrue(texts.contains("Register Child"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("Set name and favorite color"), "rendered: \(texts)")
    }

    func test_featureRow_keepsJapanese() throws {
        let texts = try renderedTexts(FeatureRow(icon: "person.badge.plus", title: "お子様を登録", description: "名前や好きな色を設定"), locale: "ja")

        XCTAssertTrue(texts.contains("お子様を登録"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("名前や好きな色を設定"), "rendered: \(texts)")
    }

    func test_tutorialStep_resolvesEnglish() throws {
        let texts = try renderedTexts(TutorialStep(number: "1", title: "記録タブを開く", description: "下部の「記録」ボタンをタップ"), locale: "en")

        XCTAssertTrue(texts.contains("1"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("Open Record tab"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("Tap the Record button at the bottom"), "rendered: \(texts)")
    }

    func test_recordFeatureRow_resolvesEnglish() throws {
        let texts = try renderedTexts(RecordFeatureRow(icon: "plus.circle", title: "記録ボタンをタップ", description: "コインを獲得！"), locale: "en")

        XCTAssertTrue(texts.contains("Tap the Record button"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("Earn coins!"), "rendered: \(texts)")
    }

    func test_completionFeature_resolvesEnglish() throws {
        let texts = try renderedTexts(CompletionFeature(icon: "house.fill", title: "ホーム画面", description: "お子様の成績を確認"), locale: "en")

        XCTAssertTrue(texts.contains("Home Screen"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("Check your child's progress"), "rendered: \(texts)")
    }
}

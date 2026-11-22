import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// 集計カードの見出しと単位が、表示言語に合わせて翻訳されること (#308)。
/// `String` で受けて `Text(title)` と書くと翻訳を引かず、en でも日本語のまま出ていた。
final class StatisticsCardTests: XCTestCase {

    private func renderedTexts(_ card: StatisticsCard, locale identifier: String) throws -> [String] {
        try card.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string(locale: Locale(identifier: identifier)) }
    }

    func test_statisticsCard_resolvesEnglish() throws {
        let card = StatisticsCard(icon: "star.fill", title: "獲得コイン", value: "60", subtitle: "コイン/回", color: .orange)
        let texts = try renderedTexts(card, locale: "en")

        XCTAssertTrue(texts.contains("Earned Coins"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("coins per chore"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("60"), "rendered: \(texts)")
    }

    func test_statisticsCard_resolvesJapaneseUnchanged() throws {
        let card = StatisticsCard(icon: "flame.fill", title: "連続記録", value: "5", subtitle: "日連続！", color: .orange)
        let texts = try renderedTexts(card, locale: "ja")

        XCTAssertTrue(texts.contains("連続記録"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("日連続！"), "rendered: \(texts)")
        XCTAssertTrue(texts.contains("5"), "rendered: \(texts)")
    }
}

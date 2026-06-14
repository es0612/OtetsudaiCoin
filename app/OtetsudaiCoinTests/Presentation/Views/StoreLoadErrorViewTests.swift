import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class StoreLoadErrorViewTests: XCTestCase {

    func test_canBeInstantiated() {
        // 生成して crash しない smoke test
        let view = StoreLoadErrorView()
        XCTAssertNotNil(view)
    }

    func test_rendersTitleAndGuidanceText() throws {
        // iOS 26 + ViewInspector 0.10.2 では accessibilityIdentifier 解決が不安定なため
        // findAll(ViewType.Text.self) で blocker (Image の AccessibilityImageLabel) を跨いで
        // Text を全列挙する（CLAUDE.md「SwiftUI View テスト戦略」）。
        // 文言の exact match は locale 依存になるため、見出し + 案内文の 2 つの Text が
        // 描画されること（locale 非依存の構造）を確認する。実文言は simulator 視覚確認で担保。
        let view = StoreLoadErrorView()
        let texts = try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertGreaterThanOrEqual(
            texts.count, 2,
            "expected title + guidance Text (>=2); rendered: \(texts)"
        )
        XCTAssertTrue(
            texts.allSatisfy { !$0.isEmpty },
            "rendered Texts should be non-empty; rendered: \(texts)"
        )
    }
}

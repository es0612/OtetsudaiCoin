import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class TaskListActionButtonsTests: XCTestCase {
    /// Label(systemImage:) は内部 Image(systemName:) が AccessibilityImageLabel blocker に
    /// なるため find(accessibilityIdentifier:) は到達不可。findAll(ViewType.Button.self) は
    /// blocker を跨いで Button を全列挙できる（CLAUDE.md SwiftUI View テスト戦略 / #84）。
    private func buttons(canSort: Bool) throws -> [InspectableView<ViewType.Button>] {
        let view = TaskListActionButtons(
            canSortByFrequency: canSort,
            onAdd: {},
            onSortByFrequency: {}
        )
        return try view.inspect().findAll(ViewType.Button.self)
    }

    func testRendersAddAndSortButtons() throws {
        let found = try buttons(canSort: true)
        XCTAssertEqual(found.count, 2, "追加 + よく使う順 の 2 ボタンを描画すべき（found: \(found.count)）")
    }

    func testSortButtonDisabledWhenCannotSort() throws {
        let found = try buttons(canSort: false)
        XCTAssertEqual(found.count, 2, "found: \(found.count)")
        // 宣言順 [追加, よく使う順]。よく使う順(index1) が disabled であるべき
        XCTAssertFalse(try found[0].isDisabled(), "追加ボタンは常に有効（index0 disabled=\(String(describing: try? found[0].isDisabled()))）")
        XCTAssertTrue(try found[1].isDisabled(), "0/1 件ではよく使う順は disabled（index1 disabled=\(String(describing: try? found[1].isDisabled()))）")
    }

    func testSortButtonEnabledWhenCanSort() throws {
        let found = try buttons(canSort: true)
        XCTAssertEqual(found.count, 2, "found: \(found.count)")
        XCTAssertFalse(try found[1].isDisabled(), "2 件以上ではよく使う順は有効（index1 disabled=\(String(describing: try? found[1].isDisabled()))）")
    }
}

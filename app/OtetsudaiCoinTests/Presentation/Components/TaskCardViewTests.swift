import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class TaskCardViewTests: XCTestCase {

    private func makeTask(name: String = "皿洗い", coinRate: Int = 10) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: coinRate)
    }

    // MARK: - #73 existingCountRow

    func test_existingCountRow_hidden_whenCountIsZero() throws {
        let view = TaskCardView(
            task: makeTask(),
            isSelected: false,
            existingCount: 0,
            onTap: {}
        )
        // 0 件のときは label が描画されない
        XCTAssertThrowsError(try view.inspect().find(viewWithAccessibilityIdentifier: "existing_count_label"))
    }

    func test_existingCountRow_visible_whenCountIsOne() throws {
        let view = TaskCardView(
            task: makeTask(),
            isSelected: false,
            existingCount: 1,
            onTap: {}
        )
        let label = try view.inspect().find(viewWithAccessibilityIdentifier: "existing_count_label")
        let text = try label.find(ViewType.Text.self).string()
        XCTAssertTrue(text.contains("1"))
    }

    func test_existingCountRow_visible_whenCountIsMany() throws {
        let view = TaskCardView(
            task: makeTask(),
            isSelected: false,
            existingCount: 3,
            onTap: {}
        )
        let label = try view.inspect().find(viewWithAccessibilityIdentifier: "existing_count_label")
        let text = try label.find(ViewType.Text.self).string()
        XCTAssertTrue(text.contains("3"))
    }
}

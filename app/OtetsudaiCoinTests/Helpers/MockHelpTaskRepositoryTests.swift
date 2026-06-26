import XCTest
@testable import OtetsudaiCoin

@MainActor
final class MockHelpTaskRepositoryTests: XCTestCase {
    /// production (CoreDataHelpTaskRepository) は `uniquingKeysWith: { first, _ in first }` で
    /// 重複 id に耐えるため、Mock も同契約（最初の位置を採用・crash しない）であるべき (#130-⑤)。
    func testUpdateSortOrdersHandlesDuplicateIdsWithoutCrash() async throws {
        let mock = MockHelpTaskRepository()
        let idA = UUID()
        let idB = UUID()
        mock.tasks = [
            HelpTask(id: idA, name: "A", isActive: true, coinRate: 10, sortOrder: 0),
            HelpTask(id: idB, name: "B", isActive: true, coinRate: 10, sortOrder: 1)
        ]

        // idA が重複した列。uniqueKeysWithValues 実装だと fatalError でクラッシュする
        try await mock.updateSortOrders([idA, idB, idA])

        let a = mock.tasks.first { $0.id == idA }
        let b = mock.tasks.first { $0.id == idB }
        XCTAssertEqual(a?.sortOrder, 0, "重複 id は最初の位置 (0) を採用すべき")
        XCTAssertEqual(b?.sortOrder, 1, "重複しない id は位置を保持すべき")
    }
}

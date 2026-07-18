import XCTest
import CoreData
@testable import OtetsudaiCoin

@MainActor
final class CoreDataHelpTaskRepositoryTests: XCTestCase {
    private var repository: CoreDataHelpTaskRepository!
    private var persistenceController: PersistenceController!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        repository = CoreDataHelpTaskRepository(
            context: persistenceController.container.viewContext,
            persistenceController: persistenceController
        )
    }

    override func tearDown() {
        repository = nil
        persistenceController = nil
        super.tearDown()
    }

    func testSortOrderRoundTrip() async throws {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true, coinRate: 10, sortOrder: 7)

        try await repository.save(task)
        let found = try await repository.findById(task.id)

        XCTAssertEqual(found?.sortOrder, 7)
    }

    func testSortOrderDefaultsToZeroWhenNotSpecified() async throws {
        // sortOrder 未指定 (init default 0) の save → migration 既存行と同じ default 値で読めることの regression guard
        let task = HelpTask(id: UUID(), name: "デフォルト", isActive: true)

        try await repository.save(task)
        let found = try await repository.findById(task.id)

        XCTAssertEqual(found?.sortOrder, 0)
    }

    func testUpdatePersistsSortOrder() async throws {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true, coinRate: 10, sortOrder: 1)
        try await repository.save(task)

        try await repository.update(task.updatingSortOrder(4))
        let found = try await repository.findById(task.id)

        XCTAssertEqual(found?.sortOrder, 4)
    }

    func testFindAllSortsBySortOrderThenName() async throws {
        // sortOrder 同値 (0) は name 昇順、それ以外は sortOrder 昇順
        try await repository.save(HelpTask(id: UUID(), name: "B食器を出す", isActive: true, coinRate: 10, sortOrder: 0))
        try await repository.save(HelpTask(id: UUID(), name: "Aお片付けする", isActive: true, coinRate: 10, sortOrder: 0))
        try await repository.save(HelpTask(id: UUID(), name: "Cゴミ出し", isActive: false, coinRate: 10, sortOrder: 2))

        let all = try await repository.findAll()

        XCTAssertEqual(all.map(\.name), ["Aお片付けする", "B食器を出す", "Cゴミ出し"])
    }

    func testFindActiveSortsBySortOrder() async throws {
        try await repository.save(HelpTask(id: UUID(), name: "後", isActive: true, coinRate: 10, sortOrder: 2))
        try await repository.save(HelpTask(id: UUID(), name: "先", isActive: true, coinRate: 10, sortOrder: 1))
        try await repository.save(HelpTask(id: UUID(), name: "無効", isActive: false, coinRate: 10, sortOrder: 0))

        let active = try await repository.findActive()

        XCTAssertEqual(active.map(\.name), ["先", "後"])
    }

    func testUpdateSortOrdersRenumbersInGivenOrder() async throws {
        let taskA = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10, sortOrder: 0)
        let taskB = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 10, sortOrder: 1)
        let taskC = HelpTask(id: UUID(), name: "C", isActive: true, coinRate: 10, sortOrder: 2)
        try await repository.save(taskA)
        try await repository.save(taskB)
        try await repository.save(taskC)

        try await repository.updateSortOrders([taskC.id, taskA.id, taskB.id])
        let all = try await repository.findAll()

        XCTAssertEqual(all.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(all.map(\.sortOrder), [0, 1, 2])
    }

    // MARK: - icon roundtrip (#148)

    func testSaveAndFetchPersistsIcon() async throws {
        let task = HelpTask(id: UUID(), name: "アイコン付き", isActive: true, coinRate: 10, sortOrder: 0, icon: "🧹")
        try await repository.save(task)

        let fetched = try await repository.findById(task.id)
        XCTAssertEqual(fetched?.icon, "🧹")
    }

    func testSaveAndFetchKeepsNilIcon() async throws {
        let task = HelpTask(id: UUID(), name: "アイコンなし", isActive: true, coinRate: 10, sortOrder: 0)
        try await repository.save(task)

        let fetched = try await repository.findById(task.id)
        XCTAssertNil(fetched?.icon)
    }

    func testUpdatePersistsIconChange() async throws {
        let task = HelpTask(id: UUID(), name: "更新対象", isActive: true, coinRate: 10, sortOrder: 0)
        try await repository.save(task)

        try await repository.update(task.updatingIcon("🧺"))

        let fetched = try await repository.findById(task.id)
        XCTAssertEqual(fetched?.icon, "🧺")
    }
}

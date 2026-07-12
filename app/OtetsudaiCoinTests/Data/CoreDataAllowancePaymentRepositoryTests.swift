import XCTest
import CoreData
@testable import OtetsudaiCoin

/// `CoreDataAllowancePaymentRepository` の単体テスト。
///
/// - NSInMemoryStoreType の隔離コンテナを使用（`CoreDataChildRepositoryTests` と同パターン）。
/// - 日付 fixture は CLAUDE.md の「相対日付禁止」ルールに従い固定日 (day 15) にピン留めし、
///   実行日非依存にする (#112/#114 の flake 予防)。
@MainActor
final class CoreDataAllowancePaymentRepositoryTests: XCTestCase {
    private var repository: CoreDataAllowancePaymentRepository!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()

        let persistentContainer = NSPersistentContainer(name: "OtetsudaiCoin")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]

        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }

        context = persistentContainer.viewContext
        repository = CoreDataAllowancePaymentRepository(context: context)
    }

    override func tearDown() {
        repository = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Fixtures（固定日ピン留め・実行日非依存）

    /// 2025-06-15 12:00 固定（全月に存在する安全日）
    private func fixedDate(year: Int = 2025, month: Int = 6, day: Int = 15, hour: Int = 12) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour)
        return Calendar.current.date(from: components)!
    }

    private func makePayment(
        id: UUID = UUID(),
        childId: UUID = UUID(),
        amount: Int = 500,
        month: Int = 6,
        year: Int = 2025,
        paidAt: Date? = nil,
        note: String? = nil
    ) -> AllowancePayment {
        AllowancePayment(
            id: id,
            childId: childId,
            amount: amount,
            month: month,
            year: year,
            paidAt: paidAt ?? fixedDate(),
            note: note
        )
    }

    // MARK: - save / findById

    func testSaveAndFindById_roundTripsAllFields() async throws {
        let payment = makePayment(amount: 1200, month: 6, year: 2025, note: "6月分")

        try await repository.save(payment)
        let found = try await repository.findById(payment.id)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, payment.id)
        XCTAssertEqual(found?.childId, payment.childId)
        XCTAssertEqual(found?.amount, 1200)
        XCTAssertEqual(found?.month, 6)
        XCTAssertEqual(found?.year, 2025)
        XCTAssertEqual(found?.paidAt, payment.paidAt)
        XCTAssertEqual(found?.note, "6月分")
    }

    func testSaveAndFindById_nilNoteRoundTrips() async throws {
        let payment = makePayment(note: nil)

        try await repository.save(payment)
        let found = try await repository.findById(payment.id)

        XCTAssertNotNil(found)
        XCTAssertNil(found?.note)
    }

    func testFindById_returnsNilWhenNotFound() async throws {
        let found = try await repository.findById(UUID())
        XCTAssertNil(found)
    }

    // MARK: - upsert セマンティクス（InMemory 版と同じ: id 一致で置換・重複させない）

    func testSave_sameIdTwice_upsertsInsteadOfDuplicating() async throws {
        let id = UUID()
        let childId = UUID()
        let original = makePayment(id: id, childId: childId, amount: 500, note: nil)
        let revised = makePayment(id: id, childId: childId, amount: 800, note: "増額")

        try await repository.save(original)
        try await repository.save(revised)

        let all = try await repository.findAll()
        XCTAssertEqual(all.count, 1, "同一 id の save は置換であり重複レコードを作らない")
        XCTAssertEqual(all.first?.amount, 800)
        XCTAssertEqual(all.first?.note, "増額")
    }

    func testUpdate_existingPayment_replacesFields() async throws {
        let id = UUID()
        let childId = UUID()
        let original = makePayment(id: id, childId: childId, amount: 300)
        try await repository.save(original)

        let revised = makePayment(id: id, childId: childId, amount: 999, note: "訂正")
        try await repository.update(revised)

        let found = try await repository.findById(id)
        XCTAssertEqual(found?.amount, 999)
        XCTAssertEqual(found?.note, "訂正")

        let all = try await repository.findAll()
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - findAll

    func testFindAll_returnsAllSavedPayments() async throws {
        let payment1 = makePayment(month: 5, year: 2025)
        let payment2 = makePayment(month: 6, year: 2025)

        try await repository.save(payment1)
        try await repository.save(payment2)

        let all = try await repository.findAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains(payment1))
        XCTAssertTrue(all.contains(payment2))
    }

    // MARK: - findByChildId

    func testFindByChildId_filtersAndSortsByPaidAtDescending() async throws {
        let targetChild = UUID()
        let otherChild = UUID()
        let older = makePayment(childId: targetChild, month: 5, year: 2025, paidAt: fixedDate(month: 5))
        let newer = makePayment(childId: targetChild, month: 6, year: 2025, paidAt: fixedDate(month: 6))
        let unrelated = makePayment(childId: otherChild, month: 6, year: 2025, paidAt: fixedDate(month: 6))

        try await repository.save(older)
        try await repository.save(newer)
        try await repository.save(unrelated)

        let found = try await repository.findByChildId(targetChild)

        XCTAssertEqual(found.count, 2)
        XCTAssertEqual(found.map { $0.id }, [newer.id, older.id], "paidAt 降順で返す (InMemory 版と同セマンティクス)")
    }

    // MARK: - findByChildIdAndMonth

    func testFindByChildIdAndMonth_matchesExactChildMonthYear() async throws {
        let childId = UUID()
        let target = makePayment(childId: childId, month: 6, year: 2025)
        let differentMonth = makePayment(childId: childId, month: 5, year: 2025, paidAt: fixedDate(month: 5))
        let differentYear = makePayment(childId: childId, month: 6, year: 2024, paidAt: fixedDate(year: 2024))
        let differentChild = makePayment(childId: UUID(), month: 6, year: 2025)

        try await repository.save(target)
        try await repository.save(differentMonth)
        try await repository.save(differentYear)
        try await repository.save(differentChild)

        let found = try await repository.findByChildIdAndMonth(childId, month: 6, year: 2025)

        XCTAssertEqual(found?.id, target.id)
    }

    func testFindByChildIdAndMonth_returnsNilWhenNoMatch() async throws {
        let payment = makePayment(month: 6, year: 2025)
        try await repository.save(payment)

        let found = try await repository.findByChildIdAndMonth(payment.childId, month: 7, year: 2025)
        XCTAssertNil(found)
    }

    // MARK: - findByDateRange

    func testFindByDateRange_returnsInclusiveRangeSortedByPaidAtDescending() async throws {
        let inRangeOlder = makePayment(month: 5, year: 2025, paidAt: fixedDate(month: 5, day: 10))
        let inRangeNewer = makePayment(month: 5, year: 2025, paidAt: fixedDate(month: 5, day: 20))
        let beforeRange = makePayment(month: 4, year: 2025, paidAt: fixedDate(month: 4, day: 15))
        let afterRange = makePayment(month: 6, year: 2025, paidAt: fixedDate(month: 6, day: 15))

        try await repository.save(inRangeOlder)
        try await repository.save(inRangeNewer)
        try await repository.save(beforeRange)
        try await repository.save(afterRange)

        let found = try await repository.findByDateRange(
            from: fixedDate(month: 5, day: 1),
            to: fixedDate(month: 5, day: 31)
        )

        XCTAssertEqual(found.count, 2)
        XCTAssertEqual(found.map { $0.id }, [inRangeNewer.id, inRangeOlder.id], "paidAt 降順で返す")
    }

    func testFindByDateRange_boundsAreInclusive() async throws {
        let boundary = makePayment(month: 5, year: 2025, paidAt: fixedDate(month: 5, day: 15))
        try await repository.save(boundary)

        let found = try await repository.findByDateRange(
            from: fixedDate(month: 5, day: 15),
            to: fixedDate(month: 5, day: 15)
        )

        XCTAssertEqual(found.count, 1, "from/to と同時刻の paidAt は両端 inclusive で含まれる")
    }

    // MARK: - delete

    func testDelete_removesOnlyTargetPayment() async throws {
        let target = makePayment()
        let other = makePayment()
        try await repository.save(target)
        try await repository.save(other)

        try await repository.delete(target.id)

        let all = try await repository.findAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, other.id)
        let deleted = try await repository.findById(target.id)
        XCTAssertNil(deleted)
    }

    func testDelete_nonexistentIdDoesNotThrow() async throws {
        let payment = makePayment()
        try await repository.save(payment)

        try await repository.delete(UUID())

        let all = try await repository.findAll()
        XCTAssertEqual(all.count, 1)
    }
}

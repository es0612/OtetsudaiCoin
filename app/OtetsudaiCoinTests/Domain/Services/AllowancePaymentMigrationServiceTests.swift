import XCTest
@testable import OtetsudaiCoin

/// `AllowancePaymentMigrationService` (UserDefaults → Core Data one-shot 移行) の単体テスト。
///
/// - UserDefaults は `UserDefaults(suiteName:)` で隔離する（`TutorialServiceTests` と同パターン）。
/// - 日付 fixture は CLAUDE.md の「相対日付禁止」ルールに従い固定日 (2025-06-15) にピン留め。
final class AllowancePaymentMigrationServiceTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private var repository: MockAllowancePaymentRepository!
    private var service: AllowancePaymentMigrationService!
    private let suiteName = "AllowancePaymentMigrationServiceTests"

    private let legacyKey = "allowance_payments"
    private let migratedFlagKey = "allowance_payments_migrated_to_coredata"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        repository = MockAllowancePaymentRepository()
        service = AllowancePaymentMigrationService(repository: repository, userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        repository = nil
        service = nil
        super.tearDown()
    }

    // MARK: - Fixtures（固定日ピン留め・実行日非依存）

    private func fixedDate(month: Int = 6, day: Int = 15) -> Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: month, day: day, hour: 12))!
    }

    private func makePayment(month: Int = 6, note: String? = nil) -> AllowancePayment {
        AllowancePayment(
            id: UUID(),
            childId: UUID(),
            amount: 500,
            month: month,
            year: 2025,
            paidAt: fixedDate(month: month),
            note: note
        )
    }

    private func seedLegacyData(_ payments: [AllowancePayment]) throws {
        // 旧 InMemoryAllowancePaymentRepository.saveToStorage() と同じ
        // JSONEncoder デフォルト設定でシリアライズして旧キーに格納する
        let data = try JSONEncoder().encode(payments)
        userDefaults.set(data, forKey: legacyKey)
    }

    // MARK: - (a) 旧データあり → 全件移行 + フラグ + 旧キー残置

    func testMigrateIfNeeded_withLegacyData_migratesAllAndSetsFlag() async throws {
        let payments = [makePayment(month: 5, note: "5月分"), makePayment(month: 6)]
        try seedLegacyData(payments)

        await service.migrateIfNeeded()

        XCTAssertEqual(repository.payments.count, 2, "旧データ全件が Core Data 側 repository へ save される")
        XCTAssertEqual(Set(repository.payments.map { $0.id }), Set(payments.map { $0.id }))
        XCTAssertTrue(userDefaults.bool(forKey: migratedFlagKey), "移行成功時のみフラグが立つ")
        XCTAssertNotNil(userDefaults.data(forKey: legacyKey), "旧キーはロールバック安全のため残置する")
    }

    func testMigrateIfNeeded_migratedFieldsRoundTrip() async throws {
        let payment = makePayment(note: "全項目確認")
        try seedLegacyData([payment])

        await service.migrateIfNeeded()

        let migrated = repository.payments.first
        XCTAssertEqual(migrated?.id, payment.id)
        XCTAssertEqual(migrated?.childId, payment.childId)
        XCTAssertEqual(migrated?.amount, payment.amount)
        XCTAssertEqual(migrated?.month, payment.month)
        XCTAssertEqual(migrated?.year, payment.year)
        XCTAssertEqual(migrated?.paidAt, payment.paidAt)
        XCTAssertEqual(migrated?.note, "全項目確認")
    }

    // MARK: - (b) フラグ済み → 再実行しない

    func testMigrateIfNeeded_whenAlreadyMigrated_doesNothing() async throws {
        try seedLegacyData([makePayment()])
        userDefaults.set(true, forKey: migratedFlagKey)

        await service.migrateIfNeeded()

        XCTAssertTrue(repository.payments.isEmpty, "移行済みフラグがあれば旧データがあっても再移行しない")
    }

    // MARK: - (c) 旧データなし → フラグのみ

    func testMigrateIfNeeded_withoutLegacyData_setsFlagWithoutSaving() async {
        await service.migrateIfNeeded()

        XCTAssertTrue(repository.payments.isEmpty)
        XCTAssertTrue(userDefaults.bool(forKey: migratedFlagKey), "新規ユーザーは移行不要としてフラグのみ立てる")
    }

    // MARK: - (d) 旧データ破損 → クラッシュせずフラグを立てない

    func testMigrateIfNeeded_withCorruptedLegacyData_doesNotSetFlag() async {
        userDefaults.set(Data("broken json".utf8), forKey: legacyKey)

        await service.migrateIfNeeded()

        XCTAssertTrue(repository.payments.isEmpty)
        XCTAssertFalse(userDefaults.bool(forKey: migratedFlagKey), "decode 失敗時はフラグを立てない (次回起動で再試行可能)")
    }

    // MARK: - (e) save 失敗 → フラグを立てない（次回起動で再試行）

    func testMigrateIfNeeded_whenSaveFails_doesNotSetFlag() async throws {
        try seedLegacyData([makePayment()])
        repository.shouldThrowError = true

        await service.migrateIfNeeded()

        XCTAssertFalse(userDefaults.bool(forKey: migratedFlagKey), "save 失敗時はフラグを立てず次回起動で再試行する")
        XCTAssertNotNil(userDefaults.data(forKey: legacyKey), "失敗時も旧データは失われない")
    }

    func testMigrateIfNeeded_retryAfterFailure_succeeds() async throws {
        let payments = [makePayment()]
        try seedLegacyData(payments)

        repository.shouldThrowError = true
        await service.migrateIfNeeded()
        XCTAssertFalse(userDefaults.bool(forKey: migratedFlagKey))

        // 次回起動相当: 保存先が復旧していれば再試行で移行完了する
        repository.shouldThrowError = false
        await service.migrateIfNeeded()

        XCTAssertEqual(repository.payments.map { $0.id }, payments.map { $0.id })
        XCTAssertTrue(userDefaults.bool(forKey: migratedFlagKey))
    }
}

import XCTest
@testable import OtetsudaiCoin

/// `MonthlyResetService` の月・年境界の characterization テスト。
///
/// `checkAndPerformMonthlyReset()` は内部で `Date()` を直接読むため `now` は注入できない。
/// そのため fixture は「実際の当月初 (currentMonthStart)」や「前年12月」に **アンカー** し、
/// 実行日に依存しない決定的なテストにしている（CLAUDE.md の date-math flake 対策ルールに準拠）。
final class MonthlyResetServiceTests: XCTestCase {

    private var service: MonthlyResetService!
    private var mockRepository: MockHelpRecordRepository!
    private var userDefaults: UserDefaults!
    private var calendar: Calendar!

    private let suiteName = "MonthlyResetServiceTests"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        mockRepository = MockHelpRecordRepository()
        service = MonthlyResetService(helpRecordRepository: mockRepository, userDefaults: userDefaults)
        calendar = Calendar.current
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        service = nil
        mockRepository = nil
        userDefaults = nil
        calendar = nil
        super.tearDown()
    }

    // MARK: - getLastResetDate / setLastResetDate

    func testGetLastResetDate_returnsNil_whenNeverSet() {
        XCTAssertNil(service.getLastResetDate())
    }

    func testSetAndGetLastResetDate_roundTrips() {
        let date = Date()
        service.setLastResetDate(date)

        let retrieved = service.getLastResetDate()
        XCTAssertNotNil(retrieved)
        // timeIntervalSince1970 を経由して永続化されるため、その精度で一致を確認する
        XCTAssertEqual(retrieved!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - checkAndPerformMonthlyReset: 記録日更新ロジック

    func testCheckAndPerform_firstLaunch_recordsResetDate() async throws {
        // 未設定（初回起動）の状態
        XCTAssertNil(service.getLastResetDate())

        // await をまたぐ月末 straddle を避けるため now を await 前に確定しておく。
        // production の Date() は必ずこの now 以降なので stored >= currentMonthStart が成り立つ。
        let now = Date()
        let currentMonthStart = calendar.dateInterval(of: .month, for: now)!.start

        try await service.checkAndPerformMonthlyReset()

        let stored = service.getLastResetDate()
        XCTAssertNotNil(stored, "初回起動ではリセット日が記録されるべき")
        // 記録された日付は今月内（当月初以降）であるべき
        XCTAssertGreaterThanOrEqual(stored!, currentMonthStart)
    }

    func testCheckAndPerform_sameMonth_isNoOp() async throws {
        // 当月初をリセット日として設定（now と同じ月）
        let currentMonthStart = calendar.dateInterval(of: .month, for: Date())!.start
        service.setLastResetDate(currentMonthStart)

        try await service.checkAndPerformMonthlyReset()

        // 同月なので更新されず、値は不変
        let stored = service.getLastResetDate()
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored!.timeIntervalSince1970, currentMonthStart.timeIntervalSince1970, accuracy: 0.001)
    }

    func testCheckAndPerform_previousMonth_updatesResetDate() async throws {
        // now を await 前に確定し、前月にアンカーした fixture（実行日非依存 + rollover-proof）
        let now = Date()
        let currentMonthStart = calendar.dateInterval(of: .month, for: now)!.start
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
        service.setLastResetDate(previousMonth)

        try await service.checkAndPerformMonthlyReset()

        let stored = service.getLastResetDate()
        XCTAssertNotNil(stored)
        // 新しい月なのでリセット日が前進しているべき（rollover-proof な「前進」比較）
        XCTAssertGreaterThan(stored!, previousMonth)
        // 前月の別日ではなく、当月初以降へ更新されたことを pin する
        XCTAssertGreaterThanOrEqual(stored!, currentMonthStart)
    }

    func testCheckAndPerform_previousYearDecember_updatesResetDate() async throws {
        // 前年12月にアンカー。月「番号」だけで比較する退行（12 > 現在月）を検知するガード。
        let now = Date()
        let currentMonthStart = calendar.dateInterval(of: .month, for: now)!.start
        let currentYear = calendar.component(.year, from: now)
        let previousYearDecember = calendar.date(
            from: DateComponents(year: currentYear - 1, month: 12, day: 15)
        )!
        service.setLastResetDate(previousYearDecember)

        try await service.checkAndPerformMonthlyReset()

        let stored = service.getLastResetDate()
        XCTAssertNotNil(stored)
        // 前年12月は必ず当月より前 → 更新されて前進しているべき
        XCTAssertGreaterThan(stored!, previousYearDecember)
        XCTAssertGreaterThanOrEqual(stored!, currentMonthStart)
    }

    // MARK: - リセットは削除しない（履歴保持）という契約

    func testCheckAndPerform_staleMonth_doesNotDeleteRecords() async throws {
        // 記録を2件シードしておく
        let childId = UUID()
        let taskId = UUID()
        mockRepository.records = [
            HelpRecord(id: UUID(), childId: childId, helpTaskId: taskId, recordedAt: Date()),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: taskId, recordedAt: Date())
        ]

        // 前月リセット（= 月次リセットが発火する条件）
        let currentMonthStart = calendar.dateInterval(of: .month, for: Date())!.start
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
        service.setLastResetDate(previousMonth)

        try await service.checkAndPerformMonthlyReset()

        // まずリセットが実際に発火したことを確認（fixture 前提が崩れて no-op 化していないこと）
        XCTAssertGreaterThan(service.getLastResetDate()!, previousMonth, "月次リセットが発火しているべき")
        // 「リセット」はデータ削除ではなく履歴保持。記録は1件も消えていないべき。
        XCTAssertEqual(mockRepository.records.count, 2, "月次リセットは履歴を削除してはならない")
    }
}

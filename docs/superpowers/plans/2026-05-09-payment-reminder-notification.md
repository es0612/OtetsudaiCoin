# 支払いリマインド通知 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** イシュー #15「支払いのプッシュ通知リマインドもしたい」を実装する。毎月1日の指定時刻に、先月以前の未払いがあれば1通知に集約してプッシュ通知する機能を追加する。

**Architecture:** 新規 `PaymentReminderNotificationService`（Domain層）が既存の `UnpaidAllowanceDetectorService` を依存注入で利用して動的に未払いを取得し、`UNCalendarNotificationTrigger(repeats: false)` で翌月1日の指定時刻に通知をスケジュールする。Presentation層には新規 ViewModel を追加し、既存の `NotificationSettingsView` に「支払いリマインド」Section を追加する。再スケジュールはアプリ起動時と設定変更時の2タイミングで明示的に呼び出す（YAGNI: データ変更時の自動連携は今回スコープ外）。

**Tech Stack:** Swift, SwiftUI, XCTest, ViewInspector, UserNotifications framework

**Spec:** `docs/superpowers/specs/2026-05-09-payment-reminder-notification-design.md`

---

## File Structure

### 新規ファイル
| パス | 責務 |
|---|---|
| `app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift` | プロトコル定義 + 支払いリマインド通知のスケジュール本体 |
| `app/OtetsudaiCoin/Presentation/ViewModels/PaymentReminderNotificationSettingsViewModel.swift` | 設定UIのバインディング |
| `app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift` | Service の単体テスト |
| `app/OtetsudaiCoinTests/Presentation/ViewModels/PaymentReminderNotificationSettingsViewModelTests.swift` | ViewModel の単体テスト |

### 修正ファイル
| パス | 変更内容 |
|---|---|
| `app/OtetsudaiCoin/Utils/NotificationManager.swift` | `Notification.Name.navigateToHome` を追加 |
| `app/OtetsudaiCoin/AppDelegate.swift` | 通知タップ時に `payment-reminder` 識別子なら `navigateToHome` を post |
| `app/OtetsudaiCoin/Presentation/Views/NotificationSettingsView.swift` | 「支払いリマインド」Section を追加。2つの ViewModel を受け取る |
| `app/OtetsudaiCoin/Presentation/Views/SettingsView.swift` | 新 ViewModel 用のサービス・ViewModel を初期化し DI |
| `app/OtetsudaiCoin/ContentView.swift` | 起動時の `paymentReminderService.reschedule()` 呼び出し（または onReceive で遷移） |
| `app/OtetsudaiCoinTests/Helpers/NotificationTestMocks.swift` | `MockPaymentReminderNotificationService`、Repository のモック群を追加 |
| `app/OtetsudaiCoin.xcodeproj/project.pbxproj` | Xcode で新規ファイルをプロジェクトに追加（Xcodeから手動操作） |

---

## Task 0: 機能ブランチ作成 & 設計ドキュメントのコミット

**Files:**
- New branch: `feat/payment-reminder-notification`
- Commit: `docs/superpowers/specs/2026-05-09-payment-reminder-notification-design.md`, `docs/superpowers/plans/2026-05-09-payment-reminder-notification.md`

- [ ] **Step 1: リモート同期確認**

```bash
cd /Users/shinya/workspace/claude/OtetsudaiCoin
git fetch origin
git status
git log origin/main..HEAD --oneline
git log HEAD..origin/main --oneline
```

期待: ローカル main と origin/main が一致している（先行コミットなし、遅延コミットなし）。差分があれば pull --rebase で同期。

- [ ] **Step 2: 機能ブランチ作成**

```bash
git switch -c feat/payment-reminder-notification
```

- [ ] **Step 3: design/plan ドキュメントをコミット**

```bash
git add \
  docs/superpowers/specs/2026-05-09-payment-reminder-notification-design.md \
  docs/superpowers/plans/2026-05-09-payment-reminder-notification.md
git commit -m "$(cat <<'EOF'
docs: 支払いリマインド通知 (#15) の設計書と実装プラン

設計書: docs/superpowers/specs/2026-05-09-payment-reminder-notification-design.md
実装プラン: docs/superpowers/plans/2026-05-09-payment-reminder-notification.md

要件:
- 毎月1日の指定時刻にプッシュ通知
- 先月以前の未払いがある場合のみ送る
- 子供名・月・金額を具体的に表示し1通知に集約
EOF
)"
```

---

## Task 1: NotificationManager に navigateToHome を追加

**Files:**
- Modify: `app/OtetsudaiCoin/Utils/NotificationManager.swift:9` (Notification.Name 拡張に追加)

- [ ] **Step 1: テストを書く**

`app/OtetsudaiCoinTests/Utils/NotificationManagerTests.swift` を新規作成（Xcode でプロジェクトに追加すること）：

```swift
import XCTest
@testable import OtetsudaiCoin

final class NotificationManagerTests: XCTestCase {

    func testNavigateToHomeNotificationNameExists() {
        // Given/When: navigateToHome 通知名にアクセス
        let name = Notification.Name.navigateToHome

        // Then: 期待する文字列値を持つ
        XCTAssertEqual(name.rawValue, "navigateToHome")
    }
}
```

- [ ] **Step 2: テスト実行で失敗を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/NotificationManagerTests/testNavigateToHomeNotificationNameExists 2>&1 | tail -20
```

期待: コンパイルエラー `Type 'Notification.Name' has no member 'navigateToHome'`

- [ ] **Step 3: 最小実装**

`app/OtetsudaiCoin/Utils/NotificationManager.swift` の Notification.Name 拡張に1行追加：

```swift
extension Notification.Name {
    static let helpRecordUpdated = Notification.Name("helpRecordUpdated")
    static let childrenUpdated = Notification.Name("childrenUpdated")
    static let tasksUpdated = Notification.Name("tasksUpdated")
    static let navigateToRecord = Notification.Name("navigateToRecord")
    static let navigateToHome = Notification.Name("navigateToHome")  // ★追加
}
```

- [ ] **Step 4: テスト再実行で成功を確認**

同じ xcodebuild コマンドで PASS を確認。

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/Utils/NotificationManager.swift \
  app/OtetsudaiCoinTests/Utils/NotificationManagerTests.swift \
  app/OtetsudaiCoin.xcodeproj/project.pbxproj
git commit -m "feat: navigateToHome 通知名を追加 (#15)"
```

---

## Task 2: PaymentReminderNotificationServiceProtocol を定義（モック先行）

**Files:**
- Modify: `app/OtetsudaiCoinTests/Helpers/NotificationTestMocks.swift` (Mock を追加)
- Create: `app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift` (プロトコルのみ)

- [ ] **Step 1: モックの追加**

`app/OtetsudaiCoinTests/Helpers/NotificationTestMocks.swift` の末尾に追加：

```swift
// MARK: - PaymentReminderNotificationServiceProtocol のモック

class MockPaymentReminderNotificationService: PaymentReminderNotificationServiceProtocol {
    var isEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0

    var requestAuthorizationCallCount = 0
    var rescheduleCallCount = 0
    var cancelAllCallCount = 0

    var authorizationResult: Bool = true
    var rescheduleError: Error?

    func requestAuthorization() async -> Bool {
        requestAuthorizationCallCount += 1
        return authorizationResult
    }

    func reschedule() async throws {
        rescheduleCallCount += 1
        if let error = rescheduleError {
            throw error
        }
    }

    func cancelAll() {
        cancelAllCallCount += 1
    }
}
```

- [ ] **Step 2: コンパイル失敗を確認**

```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -10
```

期待: `Cannot find type 'PaymentReminderNotificationServiceProtocol' in scope`

- [ ] **Step 3: プロトコルファイルを作成**

`app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift` を新規作成：

```swift
import Foundation
import UserNotifications

// MARK: - PaymentReminderNotificationServiceProtocol

protocol PaymentReminderNotificationServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }
    var reminderHour: Int { get set }
    var reminderMinute: Int { get set }

    func requestAuthorization() async -> Bool
    func reschedule() async throws
    func cancelAll()
}
```

Xcode でファイルをプロジェクトに追加する（File → Add Files to "OtetsudaiCoin"）。

- [ ] **Step 4: コンパイル成功を確認**

同じ xcodebuild build コマンドで成功を確認。

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift \
  app/OtetsudaiCoinTests/Helpers/NotificationTestMocks.swift \
  app/OtetsudaiCoin.xcodeproj/project.pbxproj
git commit -m "feat: PaymentReminderNotificationServiceProtocol を定義 (#15)"
```

---

## Task 3: Service の基本構造とUserDefaults永続化

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift`
- Create: `app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift`

- [ ] **Step 1: テストファイルを新規作成（失敗するテストを書く）**

`app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift`：

```swift
import XCTest
import UserNotifications
@testable import OtetsudaiCoin

final class PaymentReminderNotificationServiceTests: XCTestCase {

    private var service: PaymentReminderNotificationService!
    private var mockNotificationCenter: MockNotificationCenter!
    private var userDefaults: UserDefaults!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockAllowancePaymentRepository: MockAllowancePaymentRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var unpaidDetector: UnpaidAllowanceDetectorService!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "PaymentReminderNotificationServiceTests")!
        userDefaults.removePersistentDomain(forName: "PaymentReminderNotificationServiceTests")
        mockNotificationCenter = MockNotificationCenter()
        mockChildRepository = MockChildRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockAllowancePaymentRepository = MockAllowancePaymentRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        unpaidDetector = UnpaidAllowanceDetectorService()
        service = PaymentReminderNotificationService(
            notificationCenter: mockNotificationCenter,
            userDefaults: userDefaults,
            unpaidDetector: unpaidDetector,
            childRepository: mockChildRepository,
            helpRecordRepository: mockHelpRecordRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            helpTaskRepository: mockHelpTaskRepository
        )
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "PaymentReminderNotificationServiceTests")
        service = nil
        mockNotificationCenter = nil
        userDefaults = nil
        mockChildRepository = nil
        mockHelpRecordRepository = nil
        mockAllowancePaymentRepository = nil
        mockHelpTaskRepository = nil
        unpaidDetector = nil
        super.tearDown()
    }

    // MARK: - デフォルト値

    func testDefaultValues() {
        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.reminderHour, 9)
        XCTAssertEqual(service.reminderMinute, 0)
    }

    // MARK: - UserDefaults 永続化

    func testIsEnabledPersistsToUserDefaults() {
        service.isEnabled = true
        XCTAssertTrue(userDefaults.bool(forKey: "paymentReminderNotificationEnabled"))
    }

    func testReminderHourPersistsToUserDefaults() {
        service.reminderHour = 10
        XCTAssertEqual(userDefaults.integer(forKey: "paymentReminderNotificationHour"), 10)
    }

    func testReminderMinutePersistsToUserDefaults() {
        service.reminderMinute = 30
        XCTAssertEqual(userDefaults.integer(forKey: "paymentReminderNotificationMinute"), 30)
    }

    func testLoadsPersistedValuesOnInit() {
        userDefaults.set(true, forKey: "paymentReminderNotificationEnabled")
        userDefaults.set(8, forKey: "paymentReminderNotificationHour")
        userDefaults.set(15, forKey: "paymentReminderNotificationMinute")

        let newService = PaymentReminderNotificationService(
            notificationCenter: mockNotificationCenter,
            userDefaults: userDefaults,
            unpaidDetector: unpaidDetector,
            childRepository: mockChildRepository,
            helpRecordRepository: mockHelpRecordRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            helpTaskRepository: mockHelpTaskRepository
        )

        XCTAssertTrue(newService.isEnabled)
        XCTAssertEqual(newService.reminderHour, 8)
        XCTAssertEqual(newService.reminderMinute, 15)
    }
}
```

このテストでは `MockChildRepository` などまだ存在しない型に依存している。次タスクで作成。

- [ ] **Step 2: 必要なリポジトリモックを `NotificationTestMocks.swift` に追加**

`app/OtetsudaiCoinTests/Helpers/NotificationTestMocks.swift` の末尾に追加：

```swift
// MARK: - Repository Mocks (for PaymentReminderNotificationService)

class MockChildRepository: ChildRepository {
    var children: [Child] = []
    func save(_ child: Child) async throws { children.append(child) }
    func findById(_ id: UUID) async throws -> Child? { children.first { $0.id == id } }
    func findAll() async throws -> [Child] { children }
    func delete(_ id: UUID) async throws { children.removeAll { $0.id == id } }
    func update(_ child: Child) async throws {
        if let i = children.firstIndex(where: { $0.id == child.id }) { children[i] = child }
    }
}

class MockHelpRecordRepository: HelpRecordRepository {
    var records: [HelpRecord] = []
    func save(_ helpRecord: HelpRecord) async throws { records.append(helpRecord) }
    func findById(_ id: UUID) async throws -> HelpRecord? { records.first { $0.id == id } }
    func findAll() async throws -> [HelpRecord] { records }
    func findByChildId(_ childId: UUID) async throws -> [HelpRecord] {
        records.filter { $0.childId == childId }
    }
    func findByChildIdInCurrentMonth(_ childId: UUID) async throws -> [HelpRecord] {
        let cal = Calendar.current
        let now = Date()
        let comp = cal.dateComponents([.year, .month], from: now)
        return records.filter {
            $0.childId == childId &&
            cal.dateComponents([.year, .month], from: $0.recordedAt) == comp
        }
    }
    func findByDateRange(from startDate: Date, to endDate: Date) async throws -> [HelpRecord] {
        records.filter { $0.recordedAt >= startDate && $0.recordedAt <= endDate }
    }
    func delete(_ id: UUID) async throws { records.removeAll { $0.id == id } }
    func update(_ helpRecord: HelpRecord) async throws {
        if let i = records.firstIndex(where: { $0.id == helpRecord.id }) { records[i] = helpRecord }
    }
}

class MockAllowancePaymentRepository: AllowancePaymentRepository {
    var payments: [AllowancePayment] = []
    func save(_ payment: AllowancePayment) async throws { payments.append(payment) }
    func findById(_ id: UUID) async throws -> AllowancePayment? { payments.first { $0.id == id } }
    func findAll() async throws -> [AllowancePayment] { payments }
    func findByChildId(_ childId: UUID) async throws -> [AllowancePayment] {
        payments.filter { $0.childId == childId }
    }
    func findByChildIdAndMonth(_ childId: UUID, month: Int, year: Int) async throws -> AllowancePayment? {
        payments.first { $0.childId == childId && $0.month == month && $0.year == year }
    }
    func findByDateRange(from startDate: Date, to endDate: Date) async throws -> [AllowancePayment] {
        payments.filter { $0.paidAt >= startDate && $0.paidAt <= endDate }
    }
    func delete(_ id: UUID) async throws { payments.removeAll { $0.id == id } }
    func update(_ payment: AllowancePayment) async throws {
        if let i = payments.firstIndex(where: { $0.id == payment.id }) { payments[i] = payment }
    }
}

class MockHelpTaskRepository: HelpTaskRepository {
    var tasks: [HelpTask] = []
    func save(_ helpTask: HelpTask) async throws { tasks.append(helpTask) }
    func findById(_ id: UUID) async throws -> HelpTask? { tasks.first { $0.id == id } }
    func findAll() async throws -> [HelpTask] { tasks }
    func findActive() async throws -> [HelpTask] { tasks.filter { $0.isActive } }
    func delete(_ id: UUID) async throws { tasks.removeAll { $0.id == id } }
    func update(_ helpTask: HelpTask) async throws {
        if let i = tasks.firstIndex(where: { $0.id == helpTask.id }) { tasks[i] = helpTask }
    }
}
```

注: `MockHelpTaskRepository` などが既存の `TestMocks.swift` にすでに存在する場合はそれを使い、ここでは追加しない。事前確認: `grep -n "class MockChildRepository\|class MockHelpRecordRepository\|class MockAllowancePaymentRepository\|class MockHelpTaskRepository" app/OtetsudaiCoinTests/Helpers/TestMocks.swift`

- [ ] **Step 3: テスト実行で失敗を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/PaymentReminderNotificationServiceTests 2>&1 | tail -20
```

期待: `Cannot find 'PaymentReminderNotificationService' in scope`（クラスは未実装）

- [ ] **Step 4: Service の最小実装（プロパティ + イニシャライザ）**

`app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift` のプロトコル定義の下に追加：

```swift
// MARK: - PaymentReminderNotificationService

class PaymentReminderNotificationService: PaymentReminderNotificationServiceProtocol {

    private enum UserDefaultsKey {
        static let enabled = "paymentReminderNotificationEnabled"
        static let hour = "paymentReminderNotificationHour"
        static let minute = "paymentReminderNotificationMinute"
    }

    static let notificationIdentifier = "payment-reminder"
    private static let defaultHour = 9
    private static let defaultMinute = 0

    private let notificationCenter: NotificationCenterProtocol
    private let userDefaults: UserDefaults
    private let unpaidDetector: UnpaidAllowanceDetectorService
    private let childRepository: ChildRepository
    private let helpRecordRepository: HelpRecordRepository
    private let allowancePaymentRepository: AllowancePaymentRepository
    private let helpTaskRepository: HelpTaskRepository

    var isEnabled: Bool {
        didSet { userDefaults.set(isEnabled, forKey: UserDefaultsKey.enabled) }
    }

    var reminderHour: Int {
        didSet { userDefaults.set(reminderHour, forKey: UserDefaultsKey.hour) }
    }

    var reminderMinute: Int {
        didSet { userDefaults.set(reminderMinute, forKey: UserDefaultsKey.minute) }
    }

    init(
        notificationCenter: NotificationCenterProtocol,
        userDefaults: UserDefaults,
        unpaidDetector: UnpaidAllowanceDetectorService,
        childRepository: ChildRepository,
        helpRecordRepository: HelpRecordRepository,
        allowancePaymentRepository: AllowancePaymentRepository,
        helpTaskRepository: HelpTaskRepository
    ) {
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        self.unpaidDetector = unpaidDetector
        self.childRepository = childRepository
        self.helpRecordRepository = helpRecordRepository
        self.allowancePaymentRepository = allowancePaymentRepository
        self.helpTaskRepository = helpTaskRepository

        let hasStoredHour = userDefaults.object(forKey: UserDefaultsKey.hour) != nil
        let hasStoredMinute = userDefaults.object(forKey: UserDefaultsKey.minute) != nil
        self.isEnabled = userDefaults.bool(forKey: UserDefaultsKey.enabled)
        self.reminderHour = hasStoredHour
            ? userDefaults.integer(forKey: UserDefaultsKey.hour)
            : Self.defaultHour
        self.reminderMinute = hasStoredMinute
            ? userDefaults.integer(forKey: UserDefaultsKey.minute)
            : Self.defaultMinute
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func reschedule() async throws {
        // 次タスクで実装
    }

    func cancelAll() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.notificationIdentifier]
        )
    }
}
```

- [ ] **Step 5: テスト実行で成功を確認**

同じ xcodebuild test コマンドで PASS を確認。

- [ ] **Step 6: コミット**

```bash
git add \
  app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift \
  app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift \
  app/OtetsudaiCoinTests/Helpers/NotificationTestMocks.swift \
  app/OtetsudaiCoin.xcodeproj/project.pbxproj
git commit -m "feat: PaymentReminderNotificationService の基本構造を実装 (#15)"
```

---

## Task 4: Service の requestAuthorization と cancelAll をテスト

**Files:**
- Modify: `app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift`

- [ ] **Step 1: テストを追加**

`PaymentReminderNotificationServiceTests` クラスに以下を追加：

```swift
    // MARK: - 権限リクエスト

    func testRequestAuthorizationGranted() async {
        mockNotificationCenter.grantResult = true
        let result = await service.requestAuthorization()
        XCTAssertTrue(result)
        XCTAssertEqual(mockNotificationCenter.requestAuthorizationCallCount, 1)
    }

    func testRequestAuthorizationDenied() async {
        mockNotificationCenter.grantResult = false
        let result = await service.requestAuthorization()
        XCTAssertFalse(result)
    }

    // MARK: - キャンセル

    func testCancelAllRemovesPendingPaymentReminderOnly() {
        service.cancelAll()
        XCTAssertEqual(mockNotificationCenter.removeCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers, ["payment-reminder"])
    }
```

- [ ] **Step 2: テスト実行**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/PaymentReminderNotificationServiceTests 2>&1 | tail -10
```

期待: PASS（既存実装で通るはず）

- [ ] **Step 3: コミット**

```bash
git add app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift
git commit -m "test: requestAuthorization と cancelAll のテストを追加 (#15)"
```

---

## Task 5: reschedule（無効時・未払いなし）のテストと実装

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift`
- Modify: `app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift`

- [ ] **Step 1: テストを追加**

```swift
    // MARK: - reschedule: 無効時

    func testRescheduleDoesNothingWhenDisabled() async throws {
        service.isEnabled = false
        try await service.reschedule()
        XCTAssertEqual(mockNotificationCenter.addCallCount, 0)
    }

    // MARK: - reschedule: 未払いなし

    func testRescheduleSkipsAddWhenNoUnpaid() async throws {
        // Given: 通知有効、認可OK、子供なし → 未払いゼロ
        service.isEnabled = true
        mockNotificationCenter.mockAuthorizationStatus = .authorized

        // When
        try await service.reschedule()

        // Then: cancel は呼ばれるが add は呼ばれない
        XCTAssertEqual(mockNotificationCenter.removeCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.addCallCount, 0)
    }
```

このテストは `MockNotificationCenter.authorizationStatus` プロパティに依存。次ステップで追加。

- [ ] **Step 2: NotificationCenterProtocol に currentAuthorizationStatus() メソッドを追加**

`app/OtetsudaiCoin/Domain/Services/ReminderNotificationService.swift` の冒頭部を以下に書き換える（プロトコルと拡張に新メソッドを追加）：

```swift
import Foundation
import UserNotifications

// MARK: - NotificationCenterProtocol

protocol NotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func addNotificationRequest(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func currentAuthorizationStatus() async -> UNAuthorizationStatus  // ★追加
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        try await add(request)
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {  // ★追加
        let settings = await notificationSettings()
        return settings.authorizationStatus
    }
}
```

- [ ] **Step 3: MockNotificationCenter に currentAuthorizationStatus() を実装**

`app/OtetsudaiCoinTests/Helpers/NotificationTestMocks.swift` の `MockNotificationCenter` クラスを以下に書き換える（プロパティ名 `mockAuthorizationStatus`、メソッド名 `currentAuthorizationStatus()` で名前衝突を回避）：

```swift
class MockNotificationCenter: NotificationCenterProtocol {
    var grantResult: Bool = true
    var mockAuthorizationStatus: UNAuthorizationStatus = .authorized  // ★追加（プロパティ名はメソッドと衝突しないようプレフィックス付き）

    var addCallCount = 0
    var removeCallCount = 0
    var requestAuthorizationCallCount = 0
    var currentAuthorizationStatusCallCount = 0  // ★追加
    var removedIdentifiers: [String] = []
    var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        return grantResult
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {  // ★追加
        currentAuthorizationStatusCallCount += 1
        return mockAuthorizationStatus
    }

    var addError: Error?

    func addNotificationRequest(_ request: UNNotificationRequest) async throws {
        addCallCount += 1
        addedRequests.append(request)
        if let error = addError {
            throw error
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removeCallCount += 1
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
```

注: テストファイル側で `mockNotificationCenter.mockAuthorizationStatus = .authorized` のように書いていた箇所を、プロパティ名変更に合わせて `mockNotificationCenter.mockAuthorizationStatus = .authorized` に置換すること。Task 5 以降のテストコードのプロパティ参照も同様に修正。

- [ ] **Step 4: コンパイル失敗を確認**

```bash
xcodebuild build ...
```

期待: `service.reschedule()` の実装が空のため、テストは失敗する（addCallCount の期待）。

- [ ] **Step 5: reschedule の最小実装**

`PaymentReminderNotificationService.swift` の `reschedule()` メソッドを更新：

```swift
    func reschedule() async throws {
        cancelAll()
        guard isEnabled else { return }
        guard await notificationCenter.currentAuthorizationStatus() == .authorized else { return }

        let unpaidPeriods = try await collectUnpaidPeriods()
        guard !unpaidPeriods.isEmpty else { return }

        // メッセージ組み立てとスケジュールは次タスク
    }

    private func collectUnpaidPeriods() async throws -> [(child: Child, period: UnpaidPeriod)] {
        let children = try await childRepository.findAll()
        let allTasks = try await helpTaskRepository.findAll()
        let allPayments = try await allowancePaymentRepository.findAll()

        var result: [(Child, UnpaidPeriod)] = []
        for child in children {
            let records = try await helpRecordRepository.findByChildId(child.id)
            let periods = unpaidDetector.detectUnpaidPeriods(
                childId: child.id,
                helpRecords: records,
                payments: allPayments,
                tasks: allTasks
            )
            result.append(contentsOf: periods.map { (child, $0) })
        }
        return result
    }
```

- [ ] **Step 6: テスト再実行で成功を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/PaymentReminderNotificationServiceTests/testRescheduleDoesNothingWhenDisabled \
  -only-testing:OtetsudaiCoinTests/PaymentReminderNotificationServiceTests/testRescheduleSkipsAddWhenNoUnpaid 2>&1 | tail -10
```

期待: PASS

- [ ] **Step 7: コミット**

```bash
git add \
  app/OtetsudaiCoin/Domain/Services/ReminderNotificationService.swift \
  app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift \
  app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift \
  app/OtetsudaiCoinTests/Helpers/NotificationTestMocks.swift
git commit -m "feat: reschedule 基本フロー（無効時・未払いなしスキップ）を実装 (#15)"
```

---

## Task 6: reschedule（単一未払いケース：メッセージとトリガー検証）

**Files:**
- Modify: `app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift`
- Modify: `app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift`

- [ ] **Step 1: テストを追加**

```swift
    // MARK: - reschedule: 単一未払い

    func testRescheduleAddsNotificationForSingleUnpaidPeriod() async throws {
        // Given: 1人の子供、先月の未払い記録あり
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF0000")
        mockChildRepository.children = [child]

        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [task]

        let cal = Calendar.current
        let lastMonthDate = cal.date(byAdding: .month, value: -1, to: Date())!
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: lastMonthDate)
        ]
        mockAllowancePaymentRepository.payments = []

        service.isEnabled = true
        service.reminderHour = 10
        service.reminderMinute = 30
        mockNotificationCenter.mockAuthorizationStatus = .authorized

        // When
        try await service.reschedule()

        // Then: 1通知が追加され、メッセージに金額・月・名前が含まれる
        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)
        let request = mockNotificationCenter.addedRequests.first
        XCTAssertEqual(request?.identifier, "payment-reminder")
        XCTAssertEqual(request?.content.title, "お小遣いの未払いがあります 💰")
        XCTAssertTrue(request?.content.body.contains("さくら") ?? false)
        XCTAssertTrue(request?.content.body.contains("¥100") ?? false)

        // Then: トリガーが翌月1日 10:30
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        let nextMonthFirst = cal.date(byAdding: .month, value: 1, to: cal.date(from: cal.dateComponents([.year, .month], from: Date()))!)!
        let expected = cal.dateComponents([.year, .month, .day], from: nextMonthFirst)
        XCTAssertEqual(trigger?.dateComponents.year, expected.year)
        XCTAssertEqual(trigger?.dateComponents.month, expected.month)
        XCTAssertEqual(trigger?.dateComponents.day, 1)
        XCTAssertEqual(trigger?.dateComponents.hour, 10)
        XCTAssertEqual(trigger?.dateComponents.minute, 30)
        XCTAssertEqual(trigger?.repeats, false)
    }
```

- [ ] **Step 2: テスト実行で失敗を確認（addCallCount が 0 のまま）**

- [ ] **Step 3: reschedule にメッセージ組み立てとスケジュール処理を追加**

`PaymentReminderNotificationService.swift` の `reschedule()` を完成形に：

```swift
    func reschedule() async throws {
        cancelAll()
        guard isEnabled else { return }
        guard await notificationCenter.currentAuthorizationStatus() == .authorized else { return }

        let unpaidPeriods = try await collectUnpaidPeriods()
        guard !unpaidPeriods.isEmpty else { return }

        let body = buildBody(for: unpaidPeriods)
        let triggerComponents = nextMonthFirstComponents(hour: reminderHour, minute: reminderMinute)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "お小遣いの未払いがあります 💰"
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        try await notificationCenter.addNotificationRequest(request)
    }

    private func buildBody(for unpaid: [(child: Child, period: UnpaidPeriod)]) -> String {
        let total = unpaid.reduce(0) { $0 + $1.period.expectedAmount }
        let parts = unpaid.map { "\($0.child.name)\($0.period.month)月分(¥\($0.period.expectedAmount))" }

        if unpaid.count == 1 {
            let item = unpaid[0]
            return "\(item.child.name)の\(item.period.month)月分 ¥\(item.period.expectedAmount) が未払いです"
        }
        return parts.joined(separator: "、") + " が未払いです（合計 ¥\(total)）"
    }

    private func nextMonthFirstComponents(hour: Int, minute: Int) -> DateComponents {
        let cal = Calendar.current
        let now = Date()
        let thisMonthFirst = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let nextMonthFirst = cal.date(byAdding: .month, value: 1, to: thisMonthFirst)!
        var comps = cal.dateComponents([.year, .month, .day], from: nextMonthFirst)
        comps.hour = hour
        comps.minute = minute
        return comps
    }
```

- [ ] **Step 4: テスト実行で成功を確認**

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/Domain/Services/PaymentReminderNotificationService.swift \
  app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift
git commit -m "feat: 単一未払い時のメッセージ組み立てとスケジュールを実装 (#15)"
```

---

## Task 7: reschedule（複数子供×複数月の集約）

**Files:**
- Modify: `app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift`

- [ ] **Step 1: テストを追加**

```swift
    // MARK: - reschedule: 複数集約

    func testRescheduleAggregatesMultipleChildrenAndMonths() async throws {
        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date())!
        let twoMonthsAgo = cal.date(byAdding: .month, value: -2, to: Date())!

        let child1 = Child(id: UUID(), name: "さくら", themeColor: "#FF0000")
        let child2 = Child(id: UUID(), name: "たろう", themeColor: "#00FF00")
        mockChildRepository.children = [child1, child2]

        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 500)
        mockHelpTaskRepository.tasks = [task]

        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child1.id, helpTaskId: task.id, recordedAt: lastMonth),
            HelpRecord(id: UUID(), childId: child1.id, helpTaskId: task.id, recordedAt: twoMonthsAgo),
            HelpRecord(id: UUID(), childId: child2.id, helpTaskId: task.id, recordedAt: lastMonth)
        ]
        mockAllowancePaymentRepository.payments = []

        service.isEnabled = true
        mockNotificationCenter.mockAuthorizationStatus = .authorized

        try await service.reschedule()

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)
        let body = mockNotificationCenter.addedRequests.first?.content.body ?? ""
        XCTAssertTrue(body.contains("さくら"), "さくらの未払いが含まれるべき: \(body)")
        XCTAssertTrue(body.contains("たろう"), "たろうの未払いが含まれるべき: \(body)")
        XCTAssertTrue(body.contains("合計"), "合計表示があるべき: \(body)")
        XCTAssertTrue(body.contains("¥1500"), "合計金額が表示されるべき: \(body)")
    }
```

- [ ] **Step 2: テスト実行**

期待: PASS（Task 6 の実装で複数集約も対応済み）

不一致があれば実装を確認・修正。

- [ ] **Step 3: コミット**

```bash
git add app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift
git commit -m "test: 複数子供×複数月の集約テストを追加 (#15)"
```

---

## Task 8: reschedule（年またぎと認可なしのケース）

**Files:**
- Modify: `app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift`

- [ ] **Step 1: テストを追加**

```swift
    // MARK: - reschedule: 年またぎ

    func testRescheduleHandlesYearRolloverDecemberToJanuary() async throws {
        // Given: 12月の最終日（年内）に reschedule する状況をシミュレート
        // 注: 実時間が12月でないと完全には再現できないため、ロジックの正しさを保証する単体テストとしては
        // nextMonthFirstComponents の境界処理が Calendar.date(byAdding:) を使っているかコードレビューで確認
        // ここでは、現在月が何月であれ trigger が「現在月+1」になることを検証する
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF0000")
        mockChildRepository.children = [child]
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [task]
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: lastMonth)
        ]
        service.isEnabled = true
        mockNotificationCenter.mockAuthorizationStatus = .authorized

        try await service.reschedule()

        let trigger = mockNotificationCenter.addedRequests.first?.trigger as? UNCalendarNotificationTrigger
        let cal = Calendar.current
        let now = Date()
        let nextMonth = cal.date(byAdding: .month, value: 1, to: cal.date(from: cal.dateComponents([.year, .month], from: now))!)!
        let expectedComps = cal.dateComponents([.year, .month], from: nextMonth)
        XCTAssertEqual(trigger?.dateComponents.year, expectedComps.year, "翌月の年が一致")
        XCTAssertEqual(trigger?.dateComponents.month, expectedComps.month, "翌月の月が一致")
    }

    // MARK: - reschedule: 認可なし

    func testRescheduleSkipsWhenAuthorizationDenied() async throws {
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF0000")
        mockChildRepository.children = [child]
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id,
                       recordedAt: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        ]
        service.isEnabled = true
        mockNotificationCenter.mockAuthorizationStatus = .denied

        try await service.reschedule()

        XCTAssertEqual(mockNotificationCenter.removeCallCount, 1, "cancelAll は呼ばれる")
        XCTAssertEqual(mockNotificationCenter.addCallCount, 0, "認可なしなら add されない")
    }
```

- [ ] **Step 2: テスト実行で成功確認**

- [ ] **Step 3: コミット**

```bash
git add app/OtetsudaiCoinTests/Domain/Services/PaymentReminderNotificationServiceTests.swift
git commit -m "test: 年またぎ・認可拒否時のテストを追加 (#15)"
```

---

## Task 9: PaymentReminderNotificationSettingsViewModel の実装とテスト

**Files:**
- Create: `app/OtetsudaiCoin/Presentation/ViewModels/PaymentReminderNotificationSettingsViewModel.swift`
- Create: `app/OtetsudaiCoinTests/Presentation/ViewModels/PaymentReminderNotificationSettingsViewModelTests.swift`

- [ ] **Step 1: テストを書く**

`app/OtetsudaiCoinTests/Presentation/ViewModels/PaymentReminderNotificationSettingsViewModelTests.swift`：

```swift
import XCTest
@testable import OtetsudaiCoin

final class PaymentReminderNotificationSettingsViewModelTests: XCTestCase {

    private var mockService: MockPaymentReminderNotificationService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockService = MockPaymentReminderNotificationService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    @MainActor
    func testInitialStateReflectsServiceDisabled() {
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)
        XCTAssertFalse(vm.isEnabled)
    }

    @MainActor
    func testInitialStateReflectsServiceEnabled() {
        mockService.isEnabled = true
        mockService.reminderHour = 10
        mockService.reminderMinute = 30
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)
        XCTAssertTrue(vm.isEnabled)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: vm.reminderTime)
        XCTAssertEqual(comps.hour, 10)
        XCTAssertEqual(comps.minute, 30)
    }

    @MainActor
    func testToggleOnRequestsAuthorizationAndSchedules() async {
        mockService.authorizationResult = true
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        await vm.toggleNotification(enabled: true)

        XCTAssertEqual(mockService.requestAuthorizationCallCount, 1)
        XCTAssertTrue(mockService.isEnabled)
        XCTAssertEqual(mockService.rescheduleCallCount, 1)
        XCTAssertTrue(vm.isEnabled)
    }

    @MainActor
    func testToggleOnAuthorizationDeniedKeepsDisabled() async {
        mockService.authorizationResult = false
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        await vm.toggleNotification(enabled: true)

        XCTAssertFalse(mockService.isEnabled)
        XCTAssertEqual(mockService.rescheduleCallCount, 0)
        XCTAssertFalse(vm.isEnabled)
    }

    @MainActor
    func testToggleOnRescheduleErrorRevertsState() async {
        mockService.authorizationResult = true
        mockService.rescheduleError = NSError(domain: "test", code: 1)
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        await vm.toggleNotification(enabled: true)

        XCTAssertFalse(vm.isEnabled)
        XCTAssertFalse(mockService.isEnabled)
        XCTAssertNotNil(vm.scheduleError)
    }

    @MainActor
    func testToggleOffCancelsAndDisables() async {
        mockService.isEnabled = true
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        await vm.toggleNotification(enabled: false)

        XCTAssertFalse(mockService.isEnabled)
        XCTAssertEqual(mockService.cancelAllCallCount, 1)
        XCTAssertFalse(vm.isEnabled)
    }

    @MainActor
    func testUpdateReminderTimeUpdatesServiceAndReschedulesWhenEnabled() async {
        mockService.isEnabled = true
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        var comps = DateComponents()
        comps.hour = 7
        comps.minute = 45
        let newTime = Calendar.current.date(from: comps)!
        await vm.updateReminderTime(newTime)

        XCTAssertEqual(mockService.reminderHour, 7)
        XCTAssertEqual(mockService.reminderMinute, 45)
        XCTAssertEqual(mockService.rescheduleCallCount, 1)
    }

    @MainActor
    func testUpdateReminderTimeDoesNotRescheduleWhenDisabled() async {
        mockService.isEnabled = false
        let vm = PaymentReminderNotificationSettingsViewModel(service: mockService)

        var comps = DateComponents()
        comps.hour = 7
        let newTime = Calendar.current.date(from: comps)!
        await vm.updateReminderTime(newTime)

        XCTAssertEqual(mockService.rescheduleCallCount, 0)
    }
}
```

- [ ] **Step 2: テスト実行で失敗を確認**

期待: `Cannot find 'PaymentReminderNotificationSettingsViewModel' in scope`

- [ ] **Step 3: ViewModel を実装**

`app/OtetsudaiCoin/Presentation/ViewModels/PaymentReminderNotificationSettingsViewModel.swift`：

```swift
import Foundation

@MainActor
@Observable
class PaymentReminderNotificationSettingsViewModel {

    var isEnabled: Bool
    var reminderTime: Date
    var scheduleError: Error?

    private let service: PaymentReminderNotificationServiceProtocol

    init(service: PaymentReminderNotificationServiceProtocol) {
        self.service = service
        self.isEnabled = service.isEnabled
        self.reminderTime = Self.dateFrom(hour: service.reminderHour, minute: service.reminderMinute)
    }

    func toggleNotification(enabled: Bool) async {
        if enabled {
            let granted = await service.requestAuthorization()
            if granted {
                service.isEnabled = true
                isEnabled = true
                do {
                    try await service.reschedule()
                    scheduleError = nil
                } catch {
                    scheduleError = error
                    service.isEnabled = false
                    isEnabled = false
                    service.cancelAll()
                }
            } else {
                service.isEnabled = false
                isEnabled = false
            }
        } else {
            service.isEnabled = false
            isEnabled = false
            service.cancelAll()
        }
    }

    func updateReminderTime(_ newTime: Date) async {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: newTime)
        guard let hour = comps.hour, let minute = comps.minute else { return }

        service.reminderHour = hour
        service.reminderMinute = minute
        reminderTime = newTime

        if service.isEnabled {
            do {
                try await service.reschedule()
                scheduleError = nil
            } catch {
                scheduleError = error
            }
        }
    }

    private static func dateFrom(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}
```

Xcode でファイルをプロジェクトに追加。

- [ ] **Step 4: テスト実行で成功を確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:OtetsudaiCoinTests/PaymentReminderNotificationSettingsViewModelTests 2>&1 | tail -10
```

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/Presentation/ViewModels/PaymentReminderNotificationSettingsViewModel.swift \
  app/OtetsudaiCoinTests/Presentation/ViewModels/PaymentReminderNotificationSettingsViewModelTests.swift \
  app/OtetsudaiCoin.xcodeproj/project.pbxproj
git commit -m "feat: PaymentReminderNotificationSettingsViewModel を実装 (#15)"
```

---

## Task 10: NotificationSettingsView の拡張（支払いリマインドSection追加）

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/NotificationSettingsView.swift`

- [ ] **Step 1: View を更新**

`NotificationSettingsView.swift` を全面書き換え：

```swift
import SwiftUI

struct NotificationSettingsView: View {
    @Bindable var viewModel: NotificationSettingsViewModel
    @Bindable var paymentViewModel: PaymentReminderNotificationSettingsViewModel

    var body: some View {
        Form {
            Section("リマインド通知") {
                Toggle("通知を有効にする", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { newValue in
                        Task { await viewModel.toggleNotification(enabled: newValue) }
                    }
                ))

                if viewModel.isEnabled {
                    DatePicker(
                        "通知時間",
                        selection: Binding(
                            get: { viewModel.reminderTime },
                            set: { newTime in
                                Task { await viewModel.updateReminderTime(newTime) }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            Section("支払いリマインド") {
                Toggle("通知を有効にする", isOn: Binding(
                    get: { paymentViewModel.isEnabled },
                    set: { newValue in
                        Task { await paymentViewModel.toggleNotification(enabled: newValue) }
                    }
                ))

                if paymentViewModel.isEnabled {
                    DatePicker(
                        "通知時間",
                        selection: Binding(
                            get: { paymentViewModel.reminderTime },
                            set: { newTime in
                                Task { await paymentViewModel.updateReminderTime(newTime) }
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
        .navigationTitle("通知設定")
    }
}
```

- [ ] **Step 2: ビルド失敗を確認（SettingsView が古いシグネチャで呼んでいるはず）**

```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -10
```

期待: `Missing argument for parameter 'paymentViewModel' in call`（次タスクで修正）

- [ ] **Step 3: コミットしない**

次タスクで SettingsView を修正してから一緒にコミット。

---

## Task 11: SettingsView の DI 拡張

**Files:**
- Modify: `app/OtetsudaiCoin/Presentation/Views/SettingsView.swift`

- [ ] **Step 1: SettingsView を修正**

冒頭の `@State private var notificationSettingsViewModel` の付近に追加し、init を変更：

```swift
@State private var notificationSettingsViewModel: NotificationSettingsViewModel
@State private var paymentReminderViewModel: PaymentReminderNotificationSettingsViewModel  // ★追加

@MainActor
init(viewModel: ChildManagementViewModel) {
    self.viewModel = viewModel
    let context = PersistenceController.shared.container.viewContext
    let taskRepository = CoreDataHelpTaskRepository(context: context)
    self._taskManagementViewModel = State(wrappedValue: TaskManagementViewModel(helpTaskRepository: taskRepository))

    let notificationService = ReminderNotificationService(
        notificationCenter: UNUserNotificationCenter.current(),
        userDefaults: .standard
    )
    self._notificationSettingsViewModel = State(wrappedValue: NotificationSettingsViewModel(service: notificationService))

    // ★追加: PaymentReminderNotificationService の初期化
    let childRepository = CoreDataChildRepository(context: context)
    let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
    let allowancePaymentRepository = InMemoryAllowancePaymentRepository.shared
    let paymentService = PaymentReminderNotificationService(
        notificationCenter: UNUserNotificationCenter.current(),
        userDefaults: .standard,
        unpaidDetector: UnpaidAllowanceDetectorService(),
        childRepository: childRepository,
        helpRecordRepository: helpRecordRepository,
        allowancePaymentRepository: allowancePaymentRepository,
        helpTaskRepository: taskRepository
    )
    self._paymentReminderViewModel = State(
        wrappedValue: PaymentReminderNotificationSettingsViewModel(service: paymentService)
    )
}
```

そして、NavigationLink で `NotificationSettingsView` を使う行を修正：

```swift
NavigationLink {
    NotificationSettingsView(
        viewModel: notificationSettingsViewModel,
        paymentViewModel: paymentReminderViewModel  // ★追加
    )
} label: {
    ...
}
```

- [ ] **Step 2: ビルドが通ることを確認**

```bash
xcodebuild build -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -10
```

期待: BUILD SUCCEEDED

- [ ] **Step 3: 全テストを走らせて回帰がないことを確認**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -30
```

- [ ] **Step 4: コミット**

```bash
git add \
  app/OtetsudaiCoin/Presentation/Views/NotificationSettingsView.swift \
  app/OtetsudaiCoin/Presentation/Views/SettingsView.swift
git commit -m "feat: 通知設定画面に支払いリマインド設定セクションを追加 (#15)"
```

---

## Task 12: AppDelegate の通知タップ分岐

**Files:**
- Modify: `app/OtetsudaiCoin/AppDelegate.swift`
- Modify: `app/OtetsudaiCoinTests/AppDelegateTests.swift`

- [ ] **Step 1: テストを追加**

`app/OtetsudaiCoinTests/AppDelegateTests.swift` を確認して以下のテストを追加：

```swift
    @MainActor
    func testHandlePaymentReminderTapPostsNavigateToHome() {
        // Given: AppDelegate と通知監視
        let delegate = AppDelegate()
        let expectation = expectation(forNotification: .navigateToHome, object: nil)

        // When: payment-reminder の通知タップを処理
        delegate.handleNotificationTap(identifier: "payment-reminder")

        // Then: navigateToHome 通知がポストされる
        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor
    func testHandleDailyReminderTapPostsNavigateToRecord() {
        let delegate = AppDelegate()
        let expectation = expectation(forNotification: .navigateToRecord, object: nil)

        delegate.handleNotificationTap(identifier: "daily-reminder")

        wait(for: [expectation], timeout: 1.0)
    }
```

注: 既存の `handleNotificationTap()`（引数なし）と区別するため、引数付き版を追加する。

- [ ] **Step 2: テスト実行で失敗を確認**

期待: `Cannot find 'handleNotificationTap(identifier:)'`

- [ ] **Step 3: AppDelegate を修正**

`app/OtetsudaiCoin/AppDelegate.swift` を更新：

```swift
import UIKit
import UserNotifications
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        MobileAds.shared.start(completionHandler: nil)
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationTap(identifier: response.notification.request.identifier)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Internal

    func handleNotificationTap(identifier: String) {
        switch identifier {
        case PaymentReminderNotificationService.notificationIdentifier:
            NotificationCenter.default.post(name: .navigateToHome, object: nil)
        default:
            // 既存の daily-reminder ほか
            NotificationCenter.default.post(name: .navigateToRecord, object: nil)
        }
    }
}
```

注: 既存の引数なし `handleNotificationTap()` メソッドは削除（呼び出し元がない）。既存テストで使われている場合は引数付きに置き換える。

- [ ] **Step 4: テスト実行で成功を確認**

- [ ] **Step 5: コミット**

```bash
git add \
  app/OtetsudaiCoin/AppDelegate.swift \
  app/OtetsudaiCoinTests/AppDelegateTests.swift
git commit -m "feat: 支払いリマインド通知タップ時の遷移処理を実装 (#15)"
```

---

## Task 13: ContentView で navigateToHome 受信 + 起動時 reschedule

**Files:**
- Modify: `app/OtetsudaiCoin/ContentView.swift`

- [ ] **Step 1: ContentView を修正**

`ContentView.swift` の mainAppView の `.onReceive` 部分とフィールドを追加：

```swift
@State private var paymentReminderService: PaymentReminderNotificationService

@MainActor
init() {
    let context = PersistenceController.shared.container.viewContext
    self.repositoryFactory = RepositoryFactory(context: context)
    self.viewModelFactory = ViewModelFactory(repositoryFactory: repositoryFactory)

    _childManagementViewModel = State(wrappedValue: viewModelFactory.createChildManagementViewModel())
    _homeViewModel = State(wrappedValue: viewModelFactory.createHomeViewModel())

    // 起動時 reschedule 用に保持
    let paymentService = PaymentReminderNotificationService(
        notificationCenter: UNUserNotificationCenter.current(),
        userDefaults: .standard,
        unpaidDetector: UnpaidAllowanceDetectorService(),
        childRepository: repositoryFactory.createChildRepository(),
        helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
        allowancePaymentRepository: repositoryFactory.createAllowancePaymentRepository(),
        helpTaskRepository: repositoryFactory.createHelpTaskRepository()
    )
    _paymentReminderService = State(wrappedValue: paymentService)
}
```

そして mainAppView の `.onReceive(...navigateToRecord)` の下に追加：

```swift
.onReceive(Foundation.NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
    selectedTab = 0
}
```

`.onAppear { setupInitialData() }` の中に reschedule の Task を追加。`setupInitialData` の Task ブロックの末尾（catch の前）に：

```swift
                // 支払いリマインドの起動時 reschedule
                do {
                    try await paymentReminderService.reschedule()
                } catch {
                    print("支払いリマインド reschedule エラー: \(error)")
                }
```

- [ ] **Step 2: ビルド成功を確認**

- [ ] **Step 3: 全テスト実行で回帰なしを確認**

- [ ] **Step 4: コミット**

```bash
git add app/OtetsudaiCoin/ContentView.swift
git commit -m "feat: アプリ起動時の支払いリマインド reschedule とホーム画面遷移ハンドラを追加 (#15)"
```

---

## Task 14: 統合動作確認（手動）

**Files:** なし（手動確認）

- [ ] **Step 1: シミュレータでアプリを起動して以下を確認**

1. 設定 → 通知設定を開き、「支払いリマインド」セクションが表示される
2. トグルONで通知許可ダイアログが表示
3. 許可後、DatePickerで時刻設定可能
4. 子供を作成・タスクを作成・先月日付で記録（DEBUGメニューのサンプルデータ生成が便利）
5. アプリを再起動
6. シミュレータの Features → Trigger Notification で payment-reminder 識別子の通知発火（ローカル通知のテスト）
7. 通知タップでホーム画面に遷移すること

- [ ] **Step 2: 全テストスイート実行**

```bash
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -30
```

期待: すべて PASS、回帰なし

- [ ] **Step 3: 確認結果のメモ（必要なら）**

問題があれば修正コミットを作成。なければ次タスクへ。

---

## Task 15: PR作成

**Files:** なし（git/gh操作のみ）

- [ ] **Step 1: ブランチをリモートにpush**

```bash
git push -u origin feat/payment-reminder-notification
```

- [ ] **Step 2: PR作成**

```bash
gh pr create --title "feat: 支払いリマインド通知機能を追加 (#15)" --body "$(cat <<'EOF'
## Summary

- 毎月1日の指定時刻にプッシュ通知でお小遣い未払いをリマインド
- 先月以前の未払いがあるときのみ送信。1通知に複数の未払いを集約表示
- 設定画面（通知設定）に「支払いリマインド」セクションを追加（トグル + DatePicker）
- アプリ起動時と設定変更時に自動で再スケジュール

## 設計書・実装プラン

- 設計書: \`docs/superpowers/specs/2026-05-09-payment-reminder-notification-design.md\`
- 実装プラン: \`docs/superpowers/plans/2026-05-09-payment-reminder-notification.md\`

## Test plan

- [ ] 全テストスイートが PASS（特に PaymentReminderNotificationServiceTests, PaymentReminderNotificationSettingsViewModelTests）
- [ ] シミュレータ実行: 設定画面に「支払いリマインド」セクションが表示される
- [ ] 通知ONで権限ダイアログが出る
- [ ] DEBUGサンプルデータ生成 → 翌月1日の通知が予約されることをスケジューラで確認
- [ ] 通知タップでホーム画面に遷移する

Closes #15

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: PR URL を確認・記録**

---

## Self-Review チェックリスト

- [ ] 設計書の各セクションがプランで実装されているか確認
  - 1. 背景 → Task 0 (ブランチ作成)で対応文脈
  - 2. 機能要件（タイミング・条件・内容・ON/OFF・時刻設定・タップ遷移）→ Task 5-12
  - 3. アーキテクチャ → Task 2-3, 9
  - 4. データフロー（再スケジュール）→ Task 5, 13
  - 5. UI → Task 10-11
  - 6. エラーハンドリング → Task 9
  - 7. テスト戦略 → Task 3-9 各タスクのテスト
  - 8. 留意点（年またぎ・呼び忘れ）→ Task 8（年またぎテスト）, Task 13（起動時 reschedule）

- [ ] 各タスクに `[ ]` チェックボックスがある
- [ ] コード例にプレースホルダなし
- [ ] 型名・メソッド名がタスク間で一貫
- [ ] 各タスクで `git commit` 手順が含まれる

---

## メモ・実装上の注意点

1. **Xcode へのファイル追加**: 新規 `.swift` ファイルは `xcodebuild` でビルドする前に Xcode の Project navigator で「Add Files to "OtetsudaiCoin"」操作が必要。または file system synchronized groups を使う構成へ移行する別タスクを検討。
2. **既存 `MockHelpTaskRepository` の重複**: もしすでに `app/OtetsudaiCoinTests/Helpers/TestMocks.swift` などに同名クラスが存在する場合は新規作成せず流用すること（Task 3 Step 2 の事前確認 grep を必ず実行）。
3. **`HomeRecord` 構造体のフィールド名**: 本プランではテスト用に `HelpRecord(id:, childId:, helpTaskId:, recordedAt:)` というイニシャライザを想定しているが、実際の構造体定義に合わせて引数名を調整すること（`app/OtetsudaiCoin/Domain/Entities/HelpRecord.swift` を必ず確認）。
4. **ATT・本番ID差し替え**: イシュー #21, #22 で別途トラッキング中。本PRには含めない。

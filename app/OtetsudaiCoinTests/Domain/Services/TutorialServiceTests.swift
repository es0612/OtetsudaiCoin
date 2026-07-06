import XCTest
@testable import OtetsudaiCoin

/// `TutorialService` の基本テスト（初回起動判定 / 完了状態の永続化 / `--uitesting` skip 判定）。
///
/// `UserDefaults` を注入して隔離した suite でテストする（`.standard` を汚さないため）。
final class TutorialServiceTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private let suiteName = "TutorialServiceTests"

    private let hasLaunchedBeforeKey = "hasLaunchedBefore"
    private let hasCompletedChildKey = "hasCompletedChildTutorial"
    private let hasCompletedRecordKey = "hasCompletedRecordTutorial"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    // MARK: - --uitesting skip 判定（pure static helper）

    func testIsUITesting_trueWhenFlagPresent() {
        XCTAssertTrue(TutorialService.isUITesting(arguments: ["someApp", "--uitesting"]))
    }

    func testIsUITesting_falseWhenFlagAbsent() {
        XCTAssertFalse(TutorialService.isUITesting(arguments: ["someApp", "-other"]))
        XCTAssertFalse(TutorialService.isUITesting(arguments: []))
    }

    // MARK: - 初回起動判定

    func testFirstLaunch_freshDefaults_showsTutorialAndMarksLaunched() {
        let service = TutorialService(userDefaults: userDefaults)

        XCTAssertTrue(service.isFirstLaunch, "初回起動と判定されるべき")
        XCTAssertTrue(service.showTutorial, "初回起動ではチュートリアルを表示すべき")
        XCTAssertTrue(
            userDefaults.bool(forKey: hasLaunchedBeforeKey),
            "初回起動後は hasLaunchedBefore が記録されるべき"
        )
    }

    func testReturningUser_withChildTutorialCompleted_doesNotShowTutorial() {
        // 既存ユーザー（起動済み）かつ子供チュートリアル完了済み
        userDefaults.set(true, forKey: hasLaunchedBeforeKey)
        userDefaults.set(true, forKey: hasCompletedChildKey)

        let service = TutorialService(userDefaults: userDefaults)

        XCTAssertFalse(service.isFirstLaunch)
        XCTAssertFalse(service.showTutorial, "子供チュートリアル完了済みならチュートリアルは非表示")
    }

    func testReturningUser_withoutChildTutorial_showsTutorial() {
        // 既存ユーザーだが子供チュートリアル未完了 → 表示すべき
        userDefaults.set(true, forKey: hasLaunchedBeforeKey)

        let service = TutorialService(userDefaults: userDefaults)

        XCTAssertFalse(service.isFirstLaunch)
        XCTAssertTrue(service.showTutorial, "子供未登録の既存ユーザーはチュートリアルを表示")
    }

    // MARK: - 完了状態の永続化

    func testMarkChildTutorialCompleted_persistsAcrossInstances() {
        let service = TutorialService(userDefaults: userDefaults)
        service.markChildTutorialCompleted()

        XCTAssertTrue(service.hasCompletedChildTutorial)

        // 別インスタンスでも永続化された状態が読み込まれる
        let reloaded = TutorialService(userDefaults: userDefaults)
        XCTAssertTrue(reloaded.hasCompletedChildTutorial)
    }

    // MARK: - 表示ゲートの computed property

    func testGatingProperties_reflectState() {
        let service = TutorialService(userDefaults: userDefaults)

        // 子供チュートリアル段階
        service.showTutorial = true
        service.hasCompletedChildTutorial = false
        service.hasCompletedRecordTutorial = false
        XCTAssertTrue(service.shouldShowChildTutorial)
        XCTAssertFalse(service.shouldShowRecordTutorial)

        // 記録チュートリアル段階（子供完了・記録未完了）
        service.hasCompletedChildTutorial = true
        XCTAssertFalse(service.shouldShowChildTutorial)
        XCTAssertTrue(service.shouldShowRecordTutorial)

        // 両方完了
        service.hasCompletedRecordTutorial = true
        XCTAssertFalse(service.shouldShowChildTutorial)
        XCTAssertFalse(service.shouldShowRecordTutorial)
    }

    // MARK: - リセット

    func testResetTutorial_clearsPersistedState() {
        let service = TutorialService(userDefaults: userDefaults)
        service.completeTutorial()  // 子供・記録の両方を完了状態にする

        service.resetTutorial()

        XCTAssertTrue(service.isFirstLaunch)
        XCTAssertFalse(service.hasCompletedChildTutorial)
        XCTAssertFalse(service.hasCompletedRecordTutorial)
        XCTAssertTrue(service.showTutorial)
        XCTAssertFalse(userDefaults.bool(forKey: hasLaunchedBeforeKey), "hasLaunchedBefore は消去されるべき")
        XCTAssertFalse(userDefaults.bool(forKey: hasCompletedChildKey))
        XCTAssertFalse(userDefaults.bool(forKey: hasCompletedRecordKey))
    }
}

//
//  VerificationScreenshotUITests.swift
//  OtetsudaiCoinUITests
//
//  検証専用スクショ (ASC 非提出物) を撮る。Issue #199 / #151 提案1。
//  scripts/capture-verification-screenshots.sh が
//  `xcrun simctl ui <udid> appearance {light,dark}` を切替えながらこのクラスを
//  2 回走らせ、添付名 `verify-NN-name` の PNG を
//  docs/screenshots/verification/{light,dark}/NN-name.png へ配置する (gitignored)。
//
//  ASC 提出用の ASCScreenshotUITests とは意図的に分離している:
//  - こちらは fold 下 (swipeUp 後) や sheet / NavigationLink 先 / Tutorial / Splash も撮る
//  - 出力は ASC artifact (docs/screenshots/asc/) に混ぜない
//
//  各テストメソッドは 1 cold launch。XCTest はアルファベット順に実行するため
//  testCaptureTutorial (非 --uitesting 起動) が最後に走り、それまでの --uitesting
//  起動で seed された太郎/花子が Core Data に残っている前提で Record tutorial を撮る
//  (script 側で -parallel-testing-enabled NO を付け、clone simulator への分散を防ぐ)。
//

import XCTest

final class VerificationScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Launch helpers

    /// --uitesting 起動 (tutorial skip + 太郎/花子 seed + splash skip)。ja 固定。
    private func launchMainApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "--hide-developer-tools",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        app.launch()
        let firstChild = app.buttons.matching(identifier: "child_button").firstMatch
        XCTAssertTrue(
            firstChild.waitForExistence(timeout: 15),
            "Home content (child_button) did not load within 15s"
        )
        sleep(1) // card entrance animation settle
        return app
    }

    /// 非 --uitesting 起動で Splash → Tutorial を表示させる。
    /// `-key value` 形式の launch args は UserDefaults.standard を per-launch で上書きする
    /// (simulator の erase 不要)。CLAUDE.md「Tutorial / sheet など初回状態でしか出ない UI の視覚検証」参照。
    private func launchTutorialApp(childCompleted: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasLaunchedBefore", "NO",
            "-hasCompletedChildTutorial", childCompleted ? "YES" : "NO",
            "-hasCompletedRecordTutorial", "NO",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        app.launch()
        return app
    }

    /// 文言ベースの行ボタン (HStack + SF Symbol) は symbol の accessibility label が
    /// button label に畳み込まれて exact match を外すことがあるため CONTAINS で探す。
    /// 見つからない場合は全 button label を XCTFail メッセージに載せて 1 回の red で原因を掴む
    /// (CLAUDE.md PR #183 の診断パターン)。
    private func buttonContaining(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement {
        let element = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        if !element.waitForExistence(timeout: timeout) {
            let labels = app.buttons.allElementsBoundByIndex.map(\.label)
            XCTFail("button containing '\(text)' not found. buttons=\(labels)")
        }
        return element
    }

    private func attach(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Scenes

    /// 01-home / 02-record / 03-record-scrolled / 04-settings / 05-settings-scrolled
    func testCaptureTabs() throws {
        let app = launchMainApp()
        attach(name: "verify-01-home")

        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(2)
        attach(name: "verify-02-record")
        app.swipeUp()
        sleep(1)
        attach(name: "verify-03-record-scrolled")

        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        attach(name: "verify-04-settings")
        app.swipeUp()
        sleep(1)
        attach(name: "verify-05-settings-scrolled")
    }

    /// 06-home-selected / 07-monthly-summary / 08-help-history
    func testCaptureChildDetail() throws {
        let app = launchMainApp()
        app.buttons.matching(identifier: "child_button").firstMatch.tap()
        sleep(2)
        attach(name: "verify-06-home-selected")

        let summaryEntry = app.buttons["home_monthly_summary_entry"]
        XCTAssertTrue(summaryEntry.waitForExistence(timeout: 5), "monthly summary entry missing")
        if !summaryEntry.isHittable { app.swipeUp(); sleep(1) }
        summaryEntry.tap()
        sleep(2)
        attach(name: "verify-07-monthly-summary")

        app.navigationBars.buttons.element(boundBy: 0).tap() // back
        sleep(1)
        let historyEntry = app.buttons["home_help_history_entry"]
        XCTAssertTrue(historyEntry.waitForExistence(timeout: 5), "help history entry missing")
        if !historyEntry.isHittable { app.swipeUp(); sleep(1) }
        historyEntry.tap()
        sleep(2)
        attach(name: "verify-08-help-history")
    }

    /// 09-task-management (sheet) / 10-child-form (sheet)
    func testCaptureSettingsSheets() throws {
        let app = launchMainApp()
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)

        let taskEntry = buttonContaining("お手伝いリストを編集", in: app)
        taskEntry.tap()
        let closeButton = app.buttons["閉じる"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "task management sheet did not open")
        sleep(1)
        attach(name: "verify-09-task-management")
        closeButton.tap()
        sleep(1)

        let addChild = app.buttons["add_child_button"]
        XCTAssertTrue(addChild.waitForExistence(timeout: 5), "add child button missing")
        addChild.tap()
        let cancelButton = app.buttons["cancel_button"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "child form sheet did not open")
        sleep(1)
        attach(name: "verify-10-child-form")
        cancelButton.tap()
    }

    /// 11-notification-settings (NavigationLink)
    func testCaptureNotificationSettings() throws {
        let app = launchMainApp()
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        let entry = buttonContaining("通知設定", in: app)
        entry.tap()
        sleep(2)
        attach(name: "verify-11-notification-settings")
    }

    /// 00-splash / 12-tutorial-child / 13-tutorial-record
    func testCaptureTutorial() throws {
        // Child tutorial 経路: 起動直後は SplashScreenView (2.5 秒) が出ているので先に撮る (best-effort)
        let childApp = launchTutorialApp(childCompleted: false)
        attach(name: "verify-00-splash")
        let nextButton = childApp.buttons["次へ"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 20), "child tutorial did not appear")
        sleep(1)
        attach(name: "verify-12-tutorial-child")
        childApp.terminate()

        // Record tutorial 経路: child 完了済み扱いで起動すると shouldShowRecordTutorial が true になる
        // (TutorialService.swift:84-86)
        let recordApp = launchTutorialApp(childCompleted: true)
        let recordNext = recordApp.buttons["次へ"]
        XCTAssertTrue(recordNext.waitForExistence(timeout: 20), "record tutorial did not appear")
        sleep(1)
        attach(name: "verify-13-tutorial-record")
    }
}

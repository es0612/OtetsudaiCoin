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
//  testCaptureTutorial / testCaptureTutorialSteps (非 --uitesting 起動) が最後に走る
//  (script 側で -parallel-testing-enabled NO を付け、clone simulator への分散を防ぐ)。
//  記録チュートリアルは testCaptureTutorialSteps が本番と同じ流れ (子どもチュートリアルを
//  完了して入る) で撮る (#246)。直接起動で撮っていた verify-13 は #252 で廃止 (13 は欠番)。
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
    private func launchTutorialApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasLaunchedBefore", "NO",
            "-hasCompletedChildTutorial", "NO",
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
    /// AX サイズでは List が画面外の行を作らないので、見つかるまでスクロールする (#261)。
    private func buttonContaining(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement {
        let query = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text))
        _ = query.firstMatch.waitForExistence(timeout: timeout)
        return revealButton(query, named: text, in: app)
    }

    /// `query.firstMatch` が押せる状態 (exists && isHittable) になるまでスワイプして返す。
    /// List は画面外の行を accessibility tree に出さないため、waitForExistence だけでは見つからない (#261)。
    /// 行き過ぎると上の行が消えるので、最初と各スワイプの後に毎回確認する。
    private func revealButton(
        _ query: XCUIElementQuery,
        named name: String,
        in app: XCUIApplication,
        scrollingDown: Bool = true,
        maxSwipes: Int = 4
    ) -> XCUIElement {
        let element = query.firstMatch
        for attempt in 0...maxSwipes {
            if element.exists && element.isHittable { return element }
            if attempt < maxSwipes {
                if scrollingDown { app.swipeUp() } else { app.swipeDown() }
                sleep(1)
            }
        }
        let labels = app.buttons.allElementsBoundByIndex.map(\.label)
        XCTFail("button '\(name)' not found after \(maxSwipes) swipes. buttons=\(labels)")
        return element
    }

    /// チュートリアルを全ステップ撮るための起動 (Issue #246)。`--seed-sample-children` で
    /// チュートリアルを出したまま太郎/花子を用意する (`--uitesting` はチュートリアルを飛ばす)。
    private func launchTutorialAppWithChildren() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--seed-sample-children",
            "-hasLaunchedBefore", "NO",
            "-hasCompletedChildTutorial", "NO",
            "-hasCompletedRecordTutorial", "NO",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        app.launch()
        return app
    }

    /// 「次へ」が有効になるのを待って押す。
    private func tapEnabledButton(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "\(label) not found")
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: button)
        wait(for: [enabled], timeout: 10)
        button.tap()
    }

    /// チュートリアルの裏の Home にも同じ名前のボタン (太郎 など) があるため、押せるものを選ぶ。
    /// AX サイズでは本文が縦スクロールになり、目的のボタンが下に隠れていることがあるので、
    /// 見つかるまで上へスワイプする (タスク一覧は入れ子のスクロールで、最初のスワイプは一覧側が動く)。
    private func tapHittableButton(containing text: String, in app: XCUIApplication) {
        let query = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 10), "button containing '\(text)' not found")
        // 最大 4 回スワイプし、各スワイプの後 (と最初) に押せるボタンを探す
        for attempt in 0...4 {
            if let button = query.allElementsBoundByIndex.first(where: { $0.isHittable }) {
                button.tap()
                return
            }
            if attempt < 4 { app.swipeUp() }
        }
        XCTFail("no hittable button containing '\(text)'. candidates=\(query.allElementsBoundByIndex.map { "\($0.label) \($0.frame)" })")
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

        // AX サイズでは「お手伝いリストを編集」を探して下へスクロールしているので、上へ戻して探す
        let addChild = revealButton(
            app.buttons.matching(identifier: "add_child_button"),
            named: "add_child_button",
            in: app,
            scrollingDown: false
        )
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

    /// 00-splash / 12-tutorial-child
    ///
    /// 13 は欠番 (#252)。以前は「子ども完了済み・未起動」の launch args で記録チュートリアルへ
    /// 直接起動して撮っていたが、本番ではこの組み合わせにならない (`hasLaunchedBefore` は
    /// TutorialService の init で書かれ、2 回目以降の起動では `showTutorial = !hasCompletedChildTutorial`
    /// なので記録チュートリアル自体が出ない)。同じ画面は verify-16 が本番と同じ流れで撮る。
    func testCaptureTutorial() throws {
        // 起動直後は SplashScreenView (2.5 秒) が出ているので先に撮る (best-effort)
        let app = launchTutorialApp()
        attach(name: "verify-00-splash")
        let nextButton = app.buttons["次へ"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 20), "child tutorial did not appear")
        sleep(1)
        attach(name: "verify-12-tutorial-child")
    }

    /// 14〜19: チュートリアルの各ステップ (Issue #246)。文字サイズを AX にして撮ると、
    /// 縦スクロール (TutorialStepContainer) で見出し・説明・ボタンが読める/押せるかを確かめられる。
    ///
    /// 「記録する」は押さない (記録の完了ステップは撮らない)。押すと Core Data に記録が残り、
    /// 次の撮影の 06〜08 (ホーム・月のまとめ・履歴) の数字が毎回変わって before/after 比較が壊れるため。
    ///
    /// 記録チュートリアルには、子どもチュートリアルを「完了」して入る (本番と同じ流れ)。
    /// 記録チュートリアルのデータ読み込みは、表示が false → true に切り替わったときだけ
    /// 走る (TutorialContainerView)。launch args で記録チュートリアルへ直接起動すると子どもが
    /// 空になるが、本番ではその状態にならない (#252)。
    func testCaptureTutorialSteps() throws {
        let app = launchTutorialAppWithChildren()
        XCTAssertTrue(app.buttons["次へ"].waitForExistence(timeout: 20), "child tutorial did not appear")
        tapEnabledButton("次へ", in: app)
        sleep(1)
        attach(name: "verify-14-tutorial-child-step2")
        tapEnabledButton("次へ", in: app)
        sleep(1)
        attach(name: "verify-15-tutorial-child-step3")
        tapEnabledButton("完了", in: app)

        XCTAssertTrue(app.buttons["次へ"].waitForExistence(timeout: 20), "record tutorial did not appear")
        sleep(1)
        attach(name: "verify-16-tutorial-record-step1")
        tapEnabledButton("次へ", in: app)
        sleep(1)
        attach(name: "verify-17-tutorial-record-step2")
        tapHittableButton(containing: "太郎", in: app)
        tapEnabledButton("次へ", in: app)
        sleep(1)
        attach(name: "verify-18-tutorial-record-step3")
        tapHittableButton(containing: "お風呂を入れる", in: app)
        sleep(1)
        attach(name: "verify-19-tutorial-record-step3-selected")
    }
}

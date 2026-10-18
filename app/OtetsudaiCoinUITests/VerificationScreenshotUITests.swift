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
//  記録タブのタスク一覧・子どもカードのバッジ・一括モードは testCaptureRecordTasks が
//  verify-20〜22 として撮る (#260)。
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

    /// 記録タブのカード (子ども / タスク) を、画面下の記録バーに隠れていない部分を押して選ぶ (#260)。
    ///
    /// AX サイズでは記録バーの説明文が 4 行ほどに折り返し、バーが画面の半分近くを占める。
    /// バーの裏のカードも isHittable は true になるので、そのまま tap() するとバー (最悪は
    /// record_button) を押してしまう。そこで:
    /// - 縦の ScrollView の枠 (= ナビゲーションバーの下から記録バーの上まで) を「見える窓」とし、
    ///   カードを窓の中へ動かしてから押す。カードが窓より大きいときは、窓の中に見えている部分を押す
    /// - スクロールは慣性のないドラッグ (最後に止める) で行う。swipeUp は 1 回で縦 400pt 級の
    ///   カードを窓ごと通り過ぎ、LazyVGrid から外れて見つからなくなるため
    /// - 押す・ドラッグする座標は、どれも record_button の上端より上であることを assert する
    /// `expectSelected` が true なら、押した後にカードの選択状態 (.isSelected trait) を確かめる
    /// (説明文の上を押して何も起きなかった場合を見逃さないため)。ChildCardView はこの trait を持たない。
    private func tapCardAboveRecordBar(
        containing text: String,
        in app: XCUIApplication,
        expectSelected: Bool = true,
        maxScrolls: Int = 10
    ) {
        let recordButton = app.buttons["record_button"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "record_button not found")
        let scroll = app.scrollViews.containing(.switch, identifier: "bulk_mode_toggle").firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "record tab ScrollView not found")
        let query = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text))

        for _ in 0...maxScrolls {
            let topBound = app.navigationBars.firstMatch.frame.maxY
            let barTop = scroll.frame.maxY
            let buttonTop = recordButton.frame.minY
            XCTAssertTrue(
                topBound < barTop && barTop <= buttonTop,
                "unexpected layout. nav.maxY=\(topBound) scroll=\(scroll.frame) record_button=\(recordButton.frame) scrollViews=\(app.scrollViews.allElementsBoundByIndex.map(\.frame))"
            )
            let window = barTop - topBound

            // isHittable: 裏の Home タブにある同名ボタン (太郎 など) を除く
            guard let card = query.allElementsBoundByIndex.first(where: { $0.isHittable && $0.frame.intersects(scroll.frame) }) else {
                dragContent(up: window * 0.6, in: app, topBound: topBound, barTop: barTop, buttonTop: buttonTop)
                continue
            }
            let frame = card.frame
            let fits = frame.height <= window - 16
            let sliceTop = max(frame.minY, topBound)
            let sliceBottom = min(frame.maxY, barTop)
            if (fits && frame.minY >= topBound && frame.maxY <= barTop) || (!fits && sliceBottom - sliceTop >= 60) {
                let tapY = (sliceTop + sliceBottom) / 2
                XCTAssertLessThan(tapY, buttonTop, "tap point would hit the record bar")
                card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (tapY - frame.minY) / frame.height)).tap()
                sleep(1)
                if expectSelected {
                    XCTAssertTrue(
                        card.isSelected,
                        "card '\(text)' was tapped but is not selected. card=\(card.frame) window=\(topBound)..\(barTop)"
                    )
                }
                return
            }
            // カードの上端を窓の上端へ寄せる (窓より大きいカードも、上から見えるようにする)
            let delta = min(max(frame.minY - (topBound + 8), -(window - 20)), window - 20)
            dragContent(up: delta, in: app, topBound: topBound, barTop: barTop, buttonTop: buttonTop)
        }
        XCTFail("card containing '\(text)' not brought above the record bar after \(maxScrolls) scrolls. candidates=\(query.allElementsBoundByIndex.map { "\($0.label) \($0.frame)" }) scroll=\(scroll.frame) record_button=\(recordButton.frame)")
    }

    /// 記録タブの内容を、見える窓 1 枚分 (重なり 20pt) だけ上へ送る。
    private func scrollRecordPage(in app: XCUIApplication) {
        let scroll = app.scrollViews.containing(.switch, identifier: "bulk_mode_toggle").firstMatch
        let topBound = app.navigationBars.firstMatch.frame.maxY
        let barTop = scroll.frame.maxY
        dragContent(
            up: barTop - topBound - 20,
            in: app,
            topBound: topBound,
            barTop: barTop,
            buttonTop: app.buttons["record_button"].frame.minY
        )
    }

    /// カードが画面にあり、その下端が記録バーより上 (見える窓の中) にあるか。
    private func isCardBottomInWindow(containing text: String, in app: XCUIApplication) -> Bool {
        let scroll = app.scrollViews.containing(.switch, identifier: "bulk_mode_toggle").firstMatch
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text))
            .allElementsBoundByIndex.first(where: { $0.isHittable && $0.frame.intersects(scroll.frame) })
        guard let card else { return false }
        return card.frame.maxY <= scroll.frame.maxY
    }

    /// カードの下端が記録バーの上に出るまで内容を上へ送る (下端がすでに窓の中なら何もしない)。
    private func scrollCardBottomIntoWindow(containing text: String, in app: XCUIApplication) {
        let scroll = app.scrollViews.containing(.switch, identifier: "bulk_mode_toggle").firstMatch
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text))
            .allElementsBoundByIndex.first(where: { $0.isHittable && $0.frame.intersects(scroll.frame) })
        guard let card else {
            XCTFail("card containing '\(text)' not on screen")
            return
        }
        let topBound = app.navigationBars.firstMatch.frame.maxY
        let barTop = scroll.frame.maxY
        let overflow = card.frame.maxY - (barTop - 8)
        guard overflow > 0 else { return }
        dragContent(
            up: min(overflow, barTop - topBound - 20),
            in: app,
            topBound: topBound,
            barTop: barTop,
            buttonTop: app.buttons["record_button"].frame.minY
        )
    }

    /// 内容を `up` pt だけ上へ (負なら下へ) 動かす。押しっぱなしで止めて慣性を消す。
    /// x = 8 は内容の左余白 (16pt) の中で、カードや Toggle を押さない。
    private func dragContent(up distance: CGFloat, in app: XCUIApplication, topBound: CGFloat, barTop: CGFloat, buttonTop: CGFloat) {
        let startY = distance > 0 ? barTop - 10 : topBound + 10
        let endY = startY - distance
        XCTAssertLessThan(max(startY, endY), buttonTop, "drag would touch the record bar")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: 8, dy: startY)).press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 8, dy: endY)),
            withVelocity: .slow,
            thenHoldForDuration: 0.3
        )
        sleep(1)
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

    /// 20-record-child-selected / 20-record-child-unselected / 21-record-tasks-p1〜pN / 22-record-tasks-bulk (#260)
    ///
    /// 記録タブのタスク一覧と子どもカードのバッジを AX サイズで確かめるためのシーン。
    /// 「記録する」(record_button) は押さない (Core Data に記録が残り 06〜08 の数字が揺れる)。
    func testCaptureRecordTasks() throws {
        let app = launchMainApp()
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(2)

        // 太郎は最初から選ばれている。カードを窓の中へ動かしてバッジが写るようにする
        tapCardAboveRecordBar(containing: "太郎", in: app, expectSelected: false)
        attach(name: "verify-20-record-child-selected")
        // AX サイズでは子どもカードが中身の幅になり (#260)、花子のカードが画面の右へはみ出す。
        // 子どもの行を左へ送って「タップして選択」の全体を撮る (既定サイズでは動かず 20 と同じ画面)
        let hanako = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "花子"))
            .allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(hanako, "花子 card not on screen")
        hanako?.swipeLeft()
        sleep(1)
        attach(name: "verify-20-record-child-unselected")

        tapCardAboveRecordBar(containing: "下の子の面倒を見る", in: app)
        attach(name: "verify-21-record-tasks-p1")
        // ここから一括モードを ON にするまで record_button は押せる状態。ページ送りのドラッグも
        // 一括モードの行へ戻る swipeDown (画面中央から始まる) も、記録バーより上で行う。
        // 10 件すべてのタスク名を見るため、最後のタスクの下端が窓に入るまでページを送る。
        // 枚数は文字サイズで変わる (AX 最大では 1 列のカード 1 枚がほぼ窓 1 枚分)。
        // AX 最大では app.swipeUp() が内容を動かさなかった (p1〜p3 がピクセル一致) ため、ドラッグで送る
        var page = 1
        while page < 12 && !isCardBottomInWindow(containing: "自分の部屋の掃除", in: app) {
            scrollRecordPage(in: app)
            page += 1
            attach(name: "verify-21-record-tasks-p\(page)")
        }
        XCTAssertTrue(isCardBottomInWindow(containing: "自分の部屋の掃除", in: app), "last task not reached in \(page) pages")

        // 画面上端の一括モードの行まで戻して ON にする。行の中心は Toggle のラベルの上で
        // 値が変わらないので、右端のスイッチを座標で押す (CLAUDE.md の Toggle の罠)
        let bulkToggle = revealButton(
            app.switches.matching(identifier: "bulk_mode_toggle"),
            named: "bulk_mode_toggle",
            in: app,
            scrollingDown: false,
            maxSwipes: 6
        )
        // 行がナビゲーションバーの裏にかかっていると、タップがバー側に取られて値が変わらない。
        // 一番上 (大きなタイトルが出る位置) まで戻す
        for _ in 0..<3 where bulkToggle.frame.minY < app.navigationBars.firstMatch.frame.maxY {
            app.swipeDown()
            sleep(1)
        }
        bulkToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        sleep(1)
        XCTAssertEqual(
            bulkToggle.value as? String, "1",
            "bulk mode did not turn on. switches=\(app.switches.allElementsBoundByIndex.map { "\($0.identifier) '\($0.label)' \($0.value ?? "nil") \($0.frame)" })"
        )
        tapCardAboveRecordBar(containing: "お風呂を入れる", in: app)
        // AX 最大ではカードが窓より高く、一番下の「選択中」/「選択」がバーの裏に隠れるので、
        // カードの下端を窓の下端へ合わせてから撮る (既定サイズでは動かない)
        scrollCardBottomIntoWindow(containing: "お風呂を入れる", in: app)
        attach(name: "verify-22-record-tasks-bulk")
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

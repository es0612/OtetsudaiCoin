//
//  BonusPaymentUITests.swift
//  OtetsudaiCoinUITests
//
//  Issue #279: 月のまとめの「おまけを付けて支払う」の流れを端から端まで確かめる。
//
//  なぜ VerificationScreenshotUITests と別クラスか:
//  あちらは撮影 script が毎回全部流すクラスで、合否だけを見るテストは置かない
//  (前例: FeedbackSettingsUITests)。
//
//  `--in-memory-store` で起動するので、記録と支払いはアプリの終了で消え、ほかのテストや
//  撮影 (verify-06〜08 の数字など) に残らない。サンプルの子どもには記録が無いので、
//  最初に記録タブで「お風呂を入れる」を 1 回記録して、月のまとめに支払う額を作る。
//  額はチップで入れる (typeText は Simulator のキーボードの状態でぶれるため)。

import XCTest

final class BonusPaymentUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Tests

    /// アンチゴール「支払いが面倒になる」の囲い: おまけを付けない支払いは CTA の 1 タップで終わる
    func testPlainPaymentTakesOneTap() {
        let app = launchApp()
        recordOneTask(in: app)
        openMonthlySummaryOfFirstChild(in: app)

        let cta = reveal(app.buttons["summary_payment_cta"], named: "summary_payment_cta", in: app)
        cta.tap()

        // 確認画面やシートを挟まずに支払いが終わる = CTA が消える
        let ctaGone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["summary_payment_cta"])
        wait(for: [ctaGone], timeout: 5)
        XCTAssertFalse(app.buttons["bonus_confirm_button"].exists, "おまけなしの支払いでシートが出ている")
        XCTAssertFalse(app.buttons["bonus_celebration_close"].exists, "おまけなしの支払いで演出が出ている")
        XCTAssertFalse(app.buttons["summary_bonus_payment_entry"].exists, "支払い済みの月におまけの入口が残っている")
        XCTAssertFalse(app.staticTexts["もらったおまけ"].exists, "おまけなしの支払いで「もらったおまけ」欄が出ている")
    }

    /// おまけの流れ: シート → スタンプ → チップ → 確定 → 演出 → 閉じる → 「もらったおまけ」欄
    func testBonusPaymentShowsCelebrationThenSummaryEntry() {
        let app = launchApp()
        recordOneTask(in: app)
        openMonthlySummaryOfFirstChild(in: app)

        reveal(app.buttons["summary_bonus_payment_entry"], named: "summary_bonus_payment_entry", in: app).tap()

        // スタンプも額も選ぶ前は確定できない
        let confirm = app.buttons["bonus_confirm_button"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "bonus sheet did not open")
        XCTAssertFalse(confirm.isEnabled, "スタンプも額も無いのに確定ボタンが押せる")

        app.buttons["bonus_stamp_effort"].tap()
        XCTAssertTrue(app.buttons["bonus_stamp_effort"].isSelected, "スタンプを押しても選択状態にならない")
        XCTAssertFalse(confirm.isEnabled, "額が 0 なのに確定ボタンが押せる")

        app.buttons["bonus_chip_50"].tap()
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: confirm)
        wait(for: [enabled], timeout: 5)
        XCTAssertTrue(confirm.label.contains("¥"), "確定ボタンのラベルに ¥ が無い: '\(confirm.label)'")
        confirm.tap()

        // 演出: スタンプ名と額は 1 つの読み上げ要素にまとまっている (.combine) ので CONTAINS で探す
        let close = app.buttons["bonus_celebration_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "celebration did not appear")
        let celebrationAmount = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "+¥50")).firstMatch
        XCTAssertTrue(
            celebrationAmount.exists,
            "演出に +¥50 が無い. labels=\(app.descendants(matching: .any).allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty })"
        )
        close.tap()
        let closeGone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: close)
        wait(for: [closeGone], timeout: 5)

        // 支払い済みになって CTA が消え、「もらったおまけ」欄に今のおまけが出る
        let ctaGone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["summary_payment_cta"])
        wait(for: [ctaGone], timeout: 5)
        let header = app.staticTexts["もらったおまけ"]
        revealUp(header, named: "もらったおまけ", in: app)
        XCTAssertTrue(app.staticTexts["+¥50"].exists, "「もらったおまけ」欄に +¥50 が無い. texts=\(app.staticTexts.allElementsBoundByIndex.map(\.label))")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "がんばったで賞")).firstMatch.exists,
            "「もらったおまけ」欄にスタンプ名が無い. texts=\(app.staticTexts.allElementsBoundByIndex.map(\.label))"
        )
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "summary_bonus_section").firstMatch.exists,
            "summary_bonus_section の identifier が見つからない"
        )
    }

    // MARK: - Helpers

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "--hide-developer-tools",
            "--in-memory-store",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        app.launch()
        XCTAssertTrue(
            app.buttons.matching(identifier: "child_button").firstMatch.waitForExistence(timeout: 15),
            "Home content (child_button) did not load within 15s"
        )
        sleep(1) // card entrance animation settle
        return app
    }

    /// 記録タブで最初から選ばれている子に「お風呂を入れる」を 1 回記録する。
    /// 既定の文字サイズでも、最初の画面はカレンダーが占めていてタスクのカードは記録バーの裏にある。
    /// カードが記録バーより上に出るまで、内容を少しずつ上へ送ってから押す (AX サイズ向けの細かい制御は
    /// VerificationScreenshotUITests の tapCardAboveRecordBar が受け持つ)。
    private func recordOneTask(in app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(2)
        let recordButton = app.buttons["record_button"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "record_button not found")
        let query = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "お風呂を入れる"))
        var card: XCUIElement?
        // 記録バーの上端 = 縦の ScrollView の下端 (バーは ScrollView の外に固定されている)
        let scroll = app.scrollViews.containing(.switch, identifier: "bulk_mode_toggle").firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), "record tab ScrollView not found")
        for _ in 0..<6 {
            let barTop = min(scroll.frame.maxY, recordButton.frame.minY)
            let topBound = app.navigationBars.firstMatch.frame.maxY
            card = query.allElementsBoundByIndex.first(where: {
                $0.isHittable && $0.frame.minY >= topBound && $0.frame.maxY < barTop - 16
            })
            if card != nil { break }
            // 慣性のないドラッグで 200pt 送る。x = 8 は内容の左余白で、カードを押さない
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: 8, dy: barTop - 40)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: 8, dy: barTop - 240)),
                withVelocity: .slow,
                thenHoldForDuration: 0.3
            )
            sleep(1)
        }
        guard let card else {
            XCTFail("お風呂を入れる card not above the record bar. candidates=\(query.allElementsBoundByIndex.map { "\($0.frame) hittable=\($0.isHittable)" }) record_button=\(recordButton.frame)")
            return
        }
        card.tap()
        sleep(1)
        XCTAssertTrue(card.isSelected, "お風呂を入れる was tapped but is not selected. frame=\(card.frame)")

        XCTAssertTrue(recordButton.isEnabled, "record_button is disabled after selecting a task")
        recordButton.tap()
        XCTAssertTrue(
            app.staticTexts["お手伝いを記録しました！"].waitForExistence(timeout: 10),
            "record did not succeed (no success message)"
        )
    }

    /// ホームで最初の子を選び、月のまとめを開く。
    private func openMonthlySummaryOfFirstChild(in app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        app.buttons.matching(identifier: "child_button").firstMatch.tap()
        sleep(1)
        reveal(app.buttons["home_monthly_summary_entry"], named: "home_monthly_summary_entry", in: app).tap()
        sleep(2)
    }

    /// 要素が押せる状態になるまで上へスワイプして返す (月のまとめの CTA はカレンダーの下にある)。
    @discardableResult
    private func reveal(_ element: XCUIElement, named name: String, in app: XCUIApplication, maxSwipes: Int = 6) -> XCUIElement {
        _ = element.waitForExistence(timeout: 3)
        for attempt in 0...maxSwipes {
            if element.exists && element.isHittable { return element }
            if attempt < maxSwipes {
                app.swipeUp()
                sleep(1)
            }
        }
        XCTFail("'\(name)' not hittable after \(maxSwipes) swipes. buttons=\(app.buttons.allElementsBoundByIndex.map(\.label))")
        return element
    }

    /// 要素が画面に入るまで下へスワイプする (支払いの後は画面の下にいて、「もらったおまけ」は上にある)。
    private func revealUp(_ element: XCUIElement, named name: String, in app: XCUIApplication, maxSwipes: Int = 6) {
        for attempt in 0...maxSwipes {
            if element.exists && element.isHittable { return }
            if attempt < maxSwipes {
                app.swipeDown()
                sleep(1)
            }
        }
        XCTFail("'\(name)' not on screen after \(maxSwipes) swipes. texts=\(app.staticTexts.allElementsBoundByIndex.map(\.label))")
    }
}

//
//  FeedbackSettingsUITests.swift
//  OtetsudaiCoinUITests
//
//  Issue #150 / PR #182 で追加された「サウンドと触覚」トグルの UI 配線を検証する。
//
//  なぜ UITest なのか:
//  - ViewModel 層 (`FeedbackSettingsViewModelTests`) と設定サービス層
//    (`FeedbackSettingsServiceTests`) は既に unit test 済み。
//  - 残る未検証区間は「Toggle の Binding が ViewModel へ書き戻り、値が永続化されるか」
//    だけだが、`SettingsView` は ViewInspector で traverse できない既知制約があり
//    (CLAUDE.md § SwiftUI View テスト戦略)、unit test では到達できない。
//  - PR #182 はこの区間を ⚠️ 未検証のまま merge されたため、ここで塞ぐ。
//
//  PR #182 の XCUITest がタップに失敗した理由 (本 PR の調査で判明):
//  `app.switches` は 1 つの Toggle につき 2 要素を返す。
//    - ラベル付きの「行」全体   (例: label='効果音',  frame=(20, 746, 400, 52))
//    - ラベル無しのスイッチ本体 (frame=(339, 758, 63, 28)) ← 行の右端
//  `XCUIElement.tap()` は要素の中心を叩くため、行要素をタップすると x≈220 の
//  「ラベル文字の上」を押すことになり、この List では値が変わらない。
//  行の右端 (スイッチ本体の位置) を狙う必要がある。

import XCTest

final class FeedbackSettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 効果音トグルを操作すると表示が切り替わり、アプリを再起動しても維持される。
    ///
    /// 「切り替わる」= Binding の setter が ViewModel へ届いている
    /// (届かなければ SwiftUI は再描画で元の値へ戻すため value は変わらない)。
    /// 「再起動後も維持」= ViewModel の didSet 経由で UserDefaults へ永続化されている。
    func testSoundToggle_flipsOnTap_andPersistsAcrossRelaunch() {
        let app = launchApp()

        let soundRow = revealFeedbackSwitchRow(in: app, boundBy: RowIndex.sound)
        let initialValue = switchValue(of: soundRow)
        let expectedAfterTap = flipped(initialValue)

        tapSwitchControl(on: soundRow)

        XCTAssertEqual(
            switchValue(of: soundRow),
            expectedAfterTap,
            "タップしても効果音トグルの値が変わらない (Binding が ViewModel へ書き戻っていない疑い)"
        )

        // 再起動して永続化を確認する
        app.terminate()
        app.launch()
        let reopenedRow = revealFeedbackSwitchRow(in: app, boundBy: RowIndex.sound)

        XCTAssertEqual(
            switchValue(of: reopenedRow),
            expectedAfterTap,
            "再起動後に効果音トグルが元へ戻っている (UserDefaults へ永続化されていない疑い)"
        )

        // 後続テスト・再実行に影響しないよう元の値へ戻す
        tapSwitchControl(on: reopenedRow)
        XCTAssertEqual(switchValue(of: reopenedRow), initialValue, "後始末のトグル操作が効いていない")
    }

    /// 触覚トグルも同様に切り替わり、効果音トグルとは独立している。
    func testHapticToggle_flipsOnTap_withoutAffectingSoundToggle() {
        let app = launchApp()

        let soundRow = revealFeedbackSwitchRow(in: app, boundBy: RowIndex.sound)
        let hapticRow = app.switches.element(boundBy: RowIndex.haptic)
        XCTAssertTrue(hapticRow.waitForExistence(timeout: 5), "触覚トグルの行が見つからない")

        let initialSound = switchValue(of: soundRow)
        let initialHaptic = switchValue(of: hapticRow)

        tapSwitchControl(on: hapticRow)

        XCTAssertEqual(
            switchValue(of: hapticRow),
            flipped(initialHaptic),
            "タップしても触覚トグルの値が変わらない"
        )
        XCTAssertEqual(
            switchValue(of: soundRow),
            initialSound,
            "触覚トグルの操作で効果音トグルまで変わっている"
        )

        tapSwitchControl(on: hapticRow)
        XCTAssertEqual(switchValue(of: hapticRow), initialHaptic, "後始末のトグル操作が効いていない")
    }

    // MARK: - Helpers

    /// `app.switches` の並び。ラベル付きの「行」要素が先に 2 つ並ぶ
    /// (SettingsView の List 上の Toggle は「サウンドと触覚」節の 2 つだけで、
    /// 通知トグルは NavigationLink 先の別画面にある)。
    /// ラベル文字列ではなく位置で参照することで locale 非依存にする。
    private enum RowIndex {
        static let sound = 0
        static let haptic = 1
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
        app.launch()
        return app
    }

    /// 設定タブへ移動し、目的のトグル行が操作可能になるまでスクロールして返す。
    private func revealFeedbackSwitchRow(
        in app: XCUIApplication,
        boundBy index: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        // --uitesting では splash が skip されるため、Home の描画完了だけ待てばよい
        let firstChild = app.buttons.matching(identifier: "child_button").firstMatch
        XCTAssertTrue(firstChild.waitForExistence(timeout: 15), "Home の描画が完了しない", file: file, line: line)

        app.tabBars.buttons.element(boundBy: 2).tap()

        let row = app.switches.element(boundBy: index)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "設定画面にトグル行が見つからない", file: file, line: line)

        // 現行 device では「サウンドと触覚」節は初期表示で収まるが、子どもの人数や
        // Dynamic Type 次第で fold の下へ回りうるのでスクロールを保険として残す。
        var swipes = 0
        while !row.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(
            row.isHittable,
            "\(swipes) 回スクロールしてもトグル行が操作可能にならない",
            file: file,
            line: line
        )
        return row
    }

    /// トグル行の右端にあるスイッチ本体をタップする。
    ///
    /// `row.tap()` は行の中心 (= ラベル文字の上) を叩いてしまい値が変わらない。
    /// スイッチ本体は行の右端にあるため、正規化座標で右寄りを指定する。
    /// 要素 index (`app.switches.element(boundBy: 2)`) でスイッチ本体を直接掴む方法もあるが、
    /// アクセシビリティツリーの形に依存するため座標指定の方が壊れにくい。
    private func tapSwitchControl(on row: XCUIElement) {
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    /// XCUIElement.value は Any? なので、Toggle の "0"/"1" を安全に取り出す。
    private func switchValue(
        of element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        guard let value = element.value as? String else {
            XCTFail("トグルの value を String として読めない: \(String(describing: element.value))", file: file, line: line)
            return ""
        }
        return value
    }

    private func flipped(_ value: String) -> String {
        value == "1" ? "0" : "1"
    }
}

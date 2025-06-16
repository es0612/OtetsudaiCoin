//
//  OtetsudaiCoinUITests.swift
//  OtetsudaiCoinUITests
//
//  Created on 2025/06/16
//

import XCTest

final class OtetsudaiCoinUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - ハッピーパステスト: お手伝い記録フロー
    
    func testHappyPath_RecordHelpTask() throws {
        // ホーム画面が表示されることを確認
        XCTAssertTrue(app.staticTexts["ホーム"].exists)
        
        // 記録タブに移動
        app.tabBars.buttons["記録"].tap()
        
        // 記録画面が表示されることを確認
        XCTAssertTrue(app.staticTexts["記録"].exists)
        
        // 子供選択エリアが表示されることを確認
        XCTAssertTrue(app.staticTexts["お手伝いする人を選んでください"].exists)
        
        // 最初の子供を選択（太郎）
        if app.buttons.matching(identifier: "child_button").count > 0 {
            app.buttons.matching(identifier: "child_button").element(boundBy: 0).tap()
        }
        
        // お手伝いタスクリストが表示されることを確認
        XCTAssertTrue(app.staticTexts["今日のお手伝い"].exists)
        
        // 最初のタスクを選択
        if app.buttons.matching(identifier: "task_button").count > 0 {
            app.buttons.matching(identifier: "task_button").element(boundBy: 0).tap()
        }
        
        // 記録ボタンをタップ
        app.buttons.matching(identifier: "record_button").firstMatch.tap()
        
        // 成功メッセージまたはアニメーションの表示を確認
        // コインアニメーションが表示される可能性があるため、少し待機
        let successExists = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '記録しました'")).firstMatch.waitForExistence(timeout: 3)
        let coinExists = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'コイン'")).firstMatch.waitForExistence(timeout: 3)
        
        XCTAssertTrue(successExists || coinExists, "記録成功の表示またはコインアニメーションが確認できませんでした")
    }
    
    // MARK: - ハッピーパステスト: ホーム画面データ表示
    
    func testHappyPath_HomeViewDataDisplay() throws {
        // ホーム画面が表示されることを確認
        XCTAssertTrue(app.staticTexts["ホーム"].exists)
        
        // 月実績エリアの表示確認
        XCTAssertTrue(app.staticTexts["今月の実績"].exists)
        
        // 連続日数エリアの表示確認
        XCTAssertTrue(app.staticTexts["連続記録"].exists)
        
        // コイン数の表示確認（数値が表示されることを確認）
        let coinLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'コイン'")).firstMatch
        XCTAssertTrue(coinLabel.exists)
        
        // 日数の表示確認
        let daysLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '日'")).firstMatch
        XCTAssertTrue(daysLabel.exists)
    }
    
    // MARK: - ハッピーパステスト: タブナビゲーション
    
    func testHappyPath_TabNavigation() throws {
        // 初期状態でホームタブが選択されていることを確認
        XCTAssertTrue(app.tabBars.buttons["ホーム"].isSelected)
        
        // 記録タブに移動
        app.tabBars.buttons["記録"].tap()
        
        // 記録タブが選択されていることを確認
        XCTAssertTrue(app.tabBars.buttons["記録"].isSelected)
        XCTAssertFalse(app.tabBars.buttons["ホーム"].isSelected)
        
        // ホームタブに戻る
        app.tabBars.buttons["ホーム"].tap()
        
        // ホームタブが再び選択されていることを確認
        XCTAssertTrue(app.tabBars.buttons["ホーム"].isSelected)
        XCTAssertFalse(app.tabBars.buttons["記録"].isSelected)
    }
    
    // MARK: - ハッピーパステスト: 子供選択機能
    
    func testHappyPath_ChildSelection() throws {
        // 記録タブに移動
        app.tabBars.buttons["記録"].tap()
        
        // 子供選択エリアが表示されることを確認
        XCTAssertTrue(app.staticTexts["お手伝いする人を選んでください"].exists)
        
        // 子供ボタンが存在することを確認
        let childButtons = app.buttons.matching(identifier: "child_button")
        XCTAssertGreaterThan(childButtons.count, 0, "子供ボタンが表示されていません")
        
        // 最初の子供を選択
        childButtons.element(boundBy: 0).tap()
        
        // タスクリストが表示されることを確認
        XCTAssertTrue(app.staticTexts["今日のお手伝い"].exists)
        
        // 別の子供が存在する場合は、選択を変更してみる
        if childButtons.count > 1 {
            childButtons.element(boundBy: 1).tap()
            
            // タスクリストが引き続き表示されることを確認
            XCTAssertTrue(app.staticTexts["今日のお手伝い"].exists)
        }
    }
    
    // MARK: - ハッピーパステスト: エラーハンドリング
    
    func testHappyPath_NoChildSelectedError() throws {
        // 記録タブに移動
        app.tabBars.buttons["記録"].tap()
        
        // 子供を選択せずに記録ボタンをタップしようとする
        // 記録ボタンが無効化されているか、エラーメッセージが表示されることを確認
        let recordButton = app.buttons.matching(identifier: "record_button").firstMatch
        
        if recordButton.exists {
            // ボタンが存在する場合、無効化されているかチェック
            XCTAssertFalse(recordButton.isEnabled, "子供が選択されていない状態で記録ボタンが有効になっています")
        } else {
            // ボタンが表示されていないことを確認（期待される動作）
            XCTAssertFalse(recordButton.exists, "子供が選択されていない状態で記録ボタンが表示されています")
        }
    }
    
    // MARK: - パフォーマンステスト
    
    func testPerformance_AppLaunch() throws {
        measure {
            let newApp = XCUIApplication()
            newApp.launch()
            
            // ホーム画面の主要要素が表示されるまでの時間を測定
            _ = newApp.staticTexts["ホーム"].waitForExistence(timeout: 5)
            
            newApp.terminate()
        }
    }
}
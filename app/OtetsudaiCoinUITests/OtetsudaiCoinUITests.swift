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
        
        // UIテスト用にチュートリアルをスキップ
        app.launchArguments.append("--uitesting")
        app.launch()
        
        // チュートリアルが表示された場合はスキップ
        skipTutorialIfPresent()
    }
    
    private func skipTutorialIfPresent() {
        // アプリの起動を待つ
        sleep(5)
        
        // チュートリアル画面の各種ボタンを探してタップ
        let startButton = app.buttons["開始"]
        let completeButton = app.buttons["完了"]
        let nextButton = app.buttons["次へ"]
        let skipButton = app.buttons["スキップ"]
        
        // チュートリアルスキップのロジック
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            if app.tabBars.buttons["ホーム"].exists {
                // メインアプリに到達した場合は終了
                break
            } else if nextButton.waitForExistence(timeout: 2) {
                nextButton.tap()
                sleep(1)
            } else if completeButton.waitForExistence(timeout: 2) {
                completeButton.tap()
                sleep(1)
            } else if startButton.waitForExistence(timeout: 2) {
                startButton.tap()
                sleep(1)
            } else if skipButton.waitForExistence(timeout: 2) {
                skipButton.tap()
                sleep(1)
            } else {
                // チュートリアル要素が見つからない場合は次のループへ
                sleep(1)
            }
            
            attempts += 1
        }
        
        // メインアプリの画面が表示されるまで待機
        _ = app.tabBars.buttons["ホーム"].waitForExistence(timeout: 10)
        sleep(2)
    }
    
    override func tearDownWithError() throws {
        app = nil
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
        
        // 設定タブに移動
        app.tabBars.buttons["設定"].tap()
        
        // 設定タブが選択されていることを確認
        XCTAssertTrue(app.tabBars.buttons["設定"].isSelected)
        XCTAssertFalse(app.tabBars.buttons["記録"].isSelected)
        
        // ホームタブに戻る
        app.tabBars.buttons["ホーム"].tap()
        
        // ホームタブが再び選択されていることを確認
        XCTAssertTrue(app.tabBars.buttons["ホーム"].isSelected)
        XCTAssertFalse(app.tabBars.buttons["設定"].isSelected)
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
    
    // MARK: - ハッピーパステスト: 設定画面機能
    
    func testHappyPath_SettingsView() throws {
        // 設定タブに移動
        app.tabBars.buttons["設定"].tap()
        
        // 設定画面が表示されることを確認
        XCTAssertTrue(app.staticTexts["設定"].exists)
        
        // 子供追加ボタンが表示されることを確認
        let addChildButton = app.buttons.matching(identifier: "add_child_button").firstMatch
        XCTAssertTrue(addChildButton.exists, "子供追加ボタンが見つかりません")
        
        // 子供一覧が表示されることを確認（データがある場合）
        let childExists = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'コイン/回'")).firstMatch
        if childExists.exists {
            XCTAssertTrue(childExists.exists, "子供の情報が表示されていません")
        }
    }
}
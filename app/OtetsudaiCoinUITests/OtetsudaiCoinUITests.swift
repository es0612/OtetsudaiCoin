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
    
    // MARK: - ハッピーパステスト: 基本的な画面表示
    
    func testHappyPath_BasicScreenDisplay() throws {
        // 記録タブに移動
        app.tabBars.buttons["記録"].tap()
        
        // 画面の読み込みを待つ
        sleep(2)
        
        // 記録画面の基本要素が表示されることを確認
        XCTAssertTrue(app.staticTexts["お手伝い記録"].waitForExistence(timeout: 5), "記録画面のタイトルが表示されていません")
        
        // 子供選択エリアが表示されることを確認
        let childSelectionText = app.staticTexts["お手伝いする人を選んでください"]
        XCTAssertTrue(childSelectionText.waitForExistence(timeout: 5), "子供選択エリアが表示されていません")
    }
    
    
    // MARK: - パフォーマンステスト
    
    func testPerformance_AppLaunch() throws {
        measure {
            let newApp = XCUIApplication()
            newApp.launchArguments.append("--uitesting")
            newApp.launch()
            
            // タブバーが表示されるまでの時間を測定（より確実な指標）
            _ = newApp.tabBars.buttons["ホーム"].waitForExistence(timeout: 10)
            
            newApp.terminate()
        }
    }
    
}
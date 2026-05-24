//
//  ASCScreenshotUITests.swift
//  OtetsudaiCoinUITests
//
//  Captures ASC localization screenshots (ja + en) for Issue #50 Phase 1 § 1.5.
//

import XCTest

final class ASCScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureScreenshots_ja() throws {
        captureScreenshots(language: "ja", locale: "ja_JP")
    }

    func testCaptureScreenshots_en() throws {
        captureScreenshots(language: "en", locale: "en_US")
    }

    private func captureScreenshots(language: String, locale: String) {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()

        // SplashScreenView は 2.5 秒 + フェードアウト 0.5 秒 で消える (SplashScreenView.swift:124)
        // 余裕を持って 4 秒待機し、tab bar 出現も待つ
        sleep(4)
        let firstTab = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(
            firstTab.waitForExistence(timeout: 10),
            "Home tab did not appear within 10 seconds for locale=\(locale)"
        )

        // Home tab (index 0) — 既に選択済み
        sleep(1)
        attach(name: "\(language)-01-home")

        // Record tab (index 1)
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(2)
        attach(name: "\(language)-02-record")

        // Settings tab (index 2)
        app.tabBars.buttons.element(boundBy: 2).tap()
        sleep(2)
        attach(name: "\(language)-03-settings")
    }

    private func attach(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

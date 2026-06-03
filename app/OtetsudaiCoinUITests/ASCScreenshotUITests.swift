//
//  ASCScreenshotUITests.swift
//  OtetsudaiCoinUITests
//
//  Captures ASC localization screenshots (ja + en) for Issue #50 Phase 1 § 1.5.
//
//  Assumes --uitesting keeps onboarding skipped on every launch — see
//  TutorialService.swift:25-30. If onboarding flow changes, this file may
//  capture leftover tutorial UI instead of the intended tabs.
//

import XCTest

final class ASCScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // NOTE: XCTest runs tests alphabetically: testCaptureScreenshots_en()
    // executes BEFORE testCaptureScreenshots_ja(). Both are isolated via
    // per-launch process args (XCUIApplication.launch() always cold-launches),
    // so order is irrelevant for correctness, but be aware when reading logs.
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
            // Issue #95: DEBUG 限定の「開発者向け」節を隠し、ASC スクショを App Store の
            // Release 実画面に忠実化する。Developer 節 (~2 セクション分) を除くことで
            // App Info(Version) 行が tab bar に被らず initial view に収まる。
            "--hide-developer-tools",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()

        // Issue #97: the in-app SplashScreenView is skipped entirely under
        // --uitesting (ContentView.swift:16), so the main UI is present from the
        // first frame — there is no splash→main crossfade to race. Previously a
        // fixed sleep + tab-existence check could capture a half-faded splash on
        // a warm 2nd launch (ja/01-home.png shipped at 1.29 MB with an orange
        // splash tint vs en's clean 154 KB). Wait for the seeded child cards so
        // Home content is fully loaded before capturing.
        let firstChild = app.buttons.matching(identifier: "child_button").firstMatch
        XCTAssertTrue(
            firstChild.waitForExistence(timeout: 15),
            "Home content (child_button) did not load within 15s for locale=\(locale)"
        )
        // Brief settle so card entrance animations finish before capture.
        sleep(1)

        // Home tab (index 0) — 既に選択済み
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

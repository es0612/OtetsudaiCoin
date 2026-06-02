import XCTest
import SwiftUI
@testable import OtetsudaiCoin

@MainActor
final class SettingsViewTests: XCTestCase {

    // SettingsView 本体は NavigationStack + List + Material + AccessibilityImageLabel の
    // 組み合わせで ViewInspector が深く traverse できない (既知制約) ため、UI 構造は
    // structural test で担保せず、ASC スクショ再撮影の目視検証に委ねる。
    // 撮影時に DEBUG 限定 Developer 節を隠す判定 (Issue #95) は純粋関数として切り出し、
    // ここで網羅する。

    #if DEBUG
    /// 撮影フラグ (--hide-developer-tools) があるとき Developer 節を隠す (= 表示しない)。
    /// ASC スクショを Release 実画面に忠実化するための挙動。
    func test_shouldShowDeveloperTools_hiddenWhenFlagPresent() {
        XCTAssertFalse(
            SettingsView.shouldShowDeveloperTools(arguments: ["--hide-developer-tools"]),
            "撮影フラグ付き起動では Developer 節を非表示にすべき"
        )
    }

    /// フラグが無い通常起動 (実機 / 開発ビルド) では従来通り Developer 節を表示する。
    func test_shouldShowDeveloperTools_shownWhenFlagAbsent() {
        XCTAssertTrue(
            SettingsView.shouldShowDeveloperTools(arguments: ["--uitesting"]),
            "撮影フラグが無い起動では Developer 節を従来通り表示すべき"
        )
    }
    #endif
}

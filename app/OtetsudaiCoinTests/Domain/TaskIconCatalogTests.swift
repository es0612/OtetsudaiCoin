import XCTest
@testable import OtetsudaiCoin

final class TaskIconCatalogTests: XCTestCase {

    func testPresetsAreUniqueNonEmptySingleGraphemes() {
        let presets = TaskIconCatalog.presets
        XCTAssertGreaterThanOrEqual(presets.count, 24, "count: \(presets.count)")
        XCTAssertEqual(Set(presets).count, presets.count, "重複あり: \(presets)")
        for emoji in presets {
            XCTAssertEqual(emoji.count, 1, "\(emoji) は 1 grapheme cluster であること")
        }
    }

    func testPresetsContainAllDefaultIcons() {
        // デフォルトタスクの絵文字は編集時にグリッドでハイライトできるよう必ず含める
        let presets = Set(TaskIconCatalog.presets)
        for (name, emoji) in HelpTask.defaultIconsByName {
            XCTAssertTrue(presets.contains(emoji), "\(name) の \(emoji) が presets にない")
        }
    }
}

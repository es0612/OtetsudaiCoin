import XCTest
@testable import OtetsudaiCoin

/// #151 提案3: 装飾アイコンを Dynamic Type に「上限つき」で追従させる clamp のテスト。
/// `@ScaledMetric` の配線は ViewInspector から読めないため、倍率 → サイズの変換だけを
/// pure helper で固定する (RecordCalendarView.clampedDayCellSize と同じ検証境界)。
final class DecorativeScaleTests: XCTestCase {

    /// 既定の文字サイズ (倍率 1.0) では今の固定値そのまま
    func test_size_atDefaultFactor_returnsBase() {
        XCTAssertEqual(DecorativeScale.size(base: 50, rawFactor: 1.0), 50)
        XCTAssertEqual(DecorativeScale.size(base: 120, rawFactor: 1.0), 120)
    }

    /// 上限 (1.3) までは倍率どおりに育つ
    func test_size_withinCap_scalesLinearly() {
        XCTAssertEqual(DecorativeScale.size(base: 80, rawFactor: 1.2), 96, accuracy: 0.001)
    }

    /// AX5 (largeTitle で約 1.76 倍) でも 1.3 倍で止まる
    func test_size_aboveCap_isClampedToMaxFactor() {
        XCTAssertEqual(DecorativeScale.maxFactor, 1.3)
        XCTAssertEqual(DecorativeScale.size(base: 80, rawFactor: 1.76), 104, accuracy: 0.001)
        XCTAssertEqual(DecorativeScale.size(base: 120, rawFactor: 3.0), 156, accuracy: 0.001)
    }

    /// 小さい文字設定 (倍率 1 未満) でも今より縮めない
    func test_size_belowDefault_isFlooredAtBase() {
        XCTAssertEqual(DecorativeScale.size(base: 50, rawFactor: 0.82), 50)
    }
}

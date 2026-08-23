import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// ViewInspector 共通 helper (#200)。
/// `find(viewWithAccessibilityIdentifier:)` は ViewInspector 0.10.2 + iOS 26 SDK で
/// systematic に効かない既知回帰があるため (CLAUDE.md「SwiftUI View テスト戦略」節)、
/// findAll ベースで blocker を跨いで収集するパターンを 1 箇所に固定する。
@MainActor
extension View {
    /// 描画された全 Text の文字列を列挙する。
    func renderedTexts() throws -> [String] {
        try inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
    }

    /// 描画された全 Shape の fill 色を列挙する。
    func renderedFills() throws -> [Color] {
        try inspect().findAll(ViewType.Shape.self).compactMap { try? $0.fillShapeStyle(Color.self) }
    }
}

extension XCTestCase {
    /// #177 項目7 で確立した AND assert (アイコン円 0.15 + カード背景 0.1 を個別検証) の共通化 (#200)。
    /// OR だと片方だけの色 regression を検出できない。両辺の検出力は PR #198 の mutation 検証で実証済み。
    @MainActor
    func assertBrandPrimaryIconAndCardFills(
        _ view: some View, file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let fills = try view.renderedFills()
        XCTAssertTrue(
            fills.contains(AccessibilityColors.brandPrimary.opacity(0.15)),
            "アイコン円の brandPrimary 0.15 が無い / observed fills: \(fills)", file: file, line: line
        )
        XCTAssertTrue(
            fills.contains(AccessibilityColors.brandPrimary.opacity(0.1)),
            "カード背景の brandPrimary 0.1 が無い / observed fills: \(fills)", file: file, line: line
        )
    }
}

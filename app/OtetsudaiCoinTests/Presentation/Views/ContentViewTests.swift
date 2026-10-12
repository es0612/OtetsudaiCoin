import XCTest
@testable import OtetsudaiCoin

final class ContentViewTests: XCTestCase {

    // サンプルの子ども (太郎 / 花子) を用意するかの判定 (Issue #246)。
    // --uitesting はチュートリアルも飛ばすため、チュートリアルを撮影する検証では
    // 子どもだけを用意する --seed-sample-children を使う。

    func test_shouldSeedSampleChildren_trueUnderUITesting() {
        XCTAssertTrue(ContentView.shouldSeedSampleChildren(arguments: ["someApp", "--uitesting"]))
    }

    func test_shouldSeedSampleChildren_trueWithSeedFlag() {
        XCTAssertTrue(ContentView.shouldSeedSampleChildren(arguments: ["someApp", "--seed-sample-children"]))
    }

    func test_shouldSeedSampleChildren_falseWithoutFlags() {
        XCTAssertFalse(ContentView.shouldSeedSampleChildren(arguments: ["someApp", "-hasLaunchedBefore", "NO"]))
        XCTAssertFalse(ContentView.shouldSeedSampleChildren(arguments: []))
    }
}

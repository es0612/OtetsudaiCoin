import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class SplashScreenViewTests: XCTestCase {

    // #18 で作り直したアイコンの絵を Splash でも見せる (#151 ダークモード1)
    func testShowsNewAppIconArt() throws {
        let view = SplashScreenView(onComplete: {})
        let names = try view.inspect().findAll(ViewType.Image.self).compactMap { try? $0.actualImage().name() }
        XCTAssertTrue(names.contains("SplashIcon"), "rendered images: \(names)")
    }
}

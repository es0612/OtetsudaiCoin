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

    // 名前だけのテストでは、アセットが消えても / dark 版が欠けても通るので、実際に読めるかを見る
    func testSplashIconAssetHasDistinctLightAndDarkImages() throws {
        let light = UIImage(named: "SplashIcon", in: .main, compatibleWith: UITraitCollection(userInterfaceStyle: .light))
        let dark = UIImage(named: "SplashIcon", in: .main, compatibleWith: UITraitCollection(userInterfaceStyle: .dark))
        let lightData = try XCTUnwrap(light?.pngData(), "light の SplashIcon が読めない")
        let darkData = try XCTUnwrap(dark?.pngData(), "dark の SplashIcon が読めない")
        XCTAssertNotEqual(lightData, darkData, "dark 版が light と同じ画像になっている (luminosity dark の登録漏れ)")
    }
}

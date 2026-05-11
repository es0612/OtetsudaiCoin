import XCTest
@testable import OtetsudaiCoin

final class AdConstantsTests: XCTestCase {

    func testApplicationIdentifierReadsFromInfoPlist() {
        let id = AdConstants.applicationIdentifier

        XCTAssertFalse(id.isEmpty, "GADApplicationIdentifier should be set in Info.plist (via build setting GAD_APPLICATION_IDENTIFIER)")
        XCTAssertTrue(id.hasPrefix("ca-app-pub-"), "App ID must begin with 'ca-app-pub-'")
        XCTAssertTrue(id.contains("~"), "App ID uses '~' as the separator between publisher and app identifier")
    }

    func testBannerAdUnitIDReadsFromInfoPlist() {
        let id = AdConstants.bannerAdUnitID

        XCTAssertFalse(id.isEmpty, "GADBannerAdUnitID should be set in Info.plist (via build setting GAD_BANNER_AD_UNIT_ID)")
        XCTAssertTrue(id.hasPrefix("ca-app-pub-"), "Ad unit ID must begin with 'ca-app-pub-'")
        XCTAssertTrue(id.contains("/"), "Banner ad unit ID uses '/' as the separator between publisher and ad unit identifier")
    }

    func testDebugConfigurationUsesGoogleTestIDs() {
        // ユニットテストは Debug ビルドで動くため、Google 公式のテスト ID が反映されている前提
        XCTAssertEqual(AdConstants.applicationIdentifier, "ca-app-pub-3940256099942544~1458002511")
        XCTAssertEqual(AdConstants.bannerAdUnitID, "ca-app-pub-3940256099942544/2934735716")
    }
}

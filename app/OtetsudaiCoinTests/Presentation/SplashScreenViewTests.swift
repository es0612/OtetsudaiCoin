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

    // MARK: - 視差効果を減らす (#151)
    // View は @Environment(\.accessibilityReduceMotion) を読んでこの plan を使う (環境値の配線はテスト外)

    // 拡大・スライド・光と点のくり返しは止め、フェードインだけ残す (HIG: 動きをディゾルブ / フェードに置き換える)
    func testReduceMotionPlanStopsMovementAndKeepsFade() {
        let plan = SplashScreenView.MotionPlan.make(reduceMotion: true)
        XCTAssertNil(plan.iconAnimation, "アイコンの拡大")
        XCTAssertNil(plan.subtitleAnimation, "サブタイトルのスライド")
        XCTAssertNil(plan.glowAnimation, "光のくり返し")
        for index in 0..<3 {
            XCTAssertNil(plan.dotAnimation(index: index), "読み込み中の点 \(index) の脈動")
        }
        XCTAssertNotNil(plan.titleAnimation, "フェードインは残す (nil の項目は、アニメーションせずに最終値へ置く)")
    }

    // 既定では今までどおり動く
    func testDefaultPlanKeepsAllAnimations() {
        let plan = SplashScreenView.MotionPlan.make(reduceMotion: false)
        XCTAssertNotNil(plan.iconAnimation)
        XCTAssertNotNil(plan.subtitleAnimation)
        XCTAssertNotNil(plan.glowAnimation)
        for index in 0..<3 {
            XCTAssertNotNil(plan.dotAnimation(index: index))
        }
        XCTAssertNotNil(plan.titleAnimation)
    }

    // iOS の起動画面 (Splash の前に出る静止画) の背景を Splash のクリームに揃え、白 / 黒からの切り替わりのちらつきを防ぐ。
    // pbxproj の設定ではなく、ビルドされた Info.plist に実際に入っているかを見る
    func testLaunchScreenUsesLaunchBackgroundColor() {
        let launchScreen = Bundle.main.infoDictionary?["UILaunchScreen"] as? [String: Any]
        XCTAssertEqual(launchScreen?["UIColorName"] as? String, "LaunchBackground", "UILaunchScreen: \(String(describing: launchScreen))")
    }
}

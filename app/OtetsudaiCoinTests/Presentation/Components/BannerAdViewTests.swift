import XCTest
import SwiftUI
import ViewInspector
import GoogleMobileAds
@testable import OtetsudaiCoin

final class BannerAdViewTests: XCTestCase {

    // MARK: - Non-personalized 広告リクエスト

    @MainActor
    func testNonPersonalizedExtrasHasNpaParameter() {
        // Given/When: Non-personalized 用の Extras を生成
        let extras = BannerAdView.makeNonPersonalizedExtras()

        // Then: npa=1 が含まれている（IDFA を使わないトラッキング無し広告）
        XCTAssertEqual(extras.additionalParameters?["npa"] as? String, "1")
    }

    @MainActor
    func testNonPersonalizedRequestIsCreated() {
        // Given/When: Non-personalized 用の Request を生成
        let request = BannerAdView.makeNonPersonalizedRequest()

        // Then: Request が生成される
        XCTAssertNotNil(request)
    }

    // MARK: - インスタンス生成

    @MainActor
    func testBannerAdViewCanBeInstantiated() {
        // Given/When: BannerAdView を生成
        let view = BannerAdView()

        // Then: インスタンスが生成される
        XCTAssertNotNil(view)
    }

    // MARK: - SwiftUIビューとしての埋め込み

    @MainActor
    func testBannerAdViewCanBeEmbeddedInVStack() throws {
        // Given: BannerAdView を VStack に埋め込んだレイアウト
        let container = VStack {
            Text("Content")
            BannerAdView()
                .frame(height: 50)
        }

        // When: ビュー階層を検査
        let inspected = try container.inspect()

        // Then: VStack 内にビューが存在する
        XCTAssertNoThrow(try inspected.find(text: "Content"))
    }

    // MARK: - TaskManagementView との統合

    @MainActor
    func testTaskManagementViewContainsBannerAdView() throws {
        // Given: TaskManagementView のための依存を準備
        let mockRepository = MockHelpTaskRepository()
        let viewModel = TaskManagementViewModel(helpTaskRepository: mockRepository)

        // When: TaskManagementView を生成
        let view = TaskManagementView(viewModel: viewModel)

        // Then: BannerAdView が含まれている
        XCTAssertNoThrow(try view.inspect().find(BannerAdView.self))
    }

    @MainActor
    func testTaskManagementViewShowsBannerAdBelowList() throws {
        // Given: タスクが存在する状態
        let mockRepository = MockHelpTaskRepository()
        mockRepository.tasks = [
            HelpTask(id: UUID(), name: "お皿洗い", isActive: true, coinRate: 10)
        ]
        let viewModel = TaskManagementViewModel(helpTaskRepository: mockRepository)
        viewModel.tasks = mockRepository.tasks

        // When: TaskManagementView を生成
        let view = TaskManagementView(viewModel: viewModel)

        // Then: リストとバナー広告の両方が含まれている
        XCTAssertNoThrow(try view.inspect().find(ViewType.List.self))
        XCTAssertNoThrow(try view.inspect().find(BannerAdView.self))
    }

    @MainActor
    func testTaskManagementViewShowsBannerAdDuringLoadingState() throws {
        // Given: ローディング中の状態
        let mockRepository = MockHelpTaskRepository()
        let viewModel = TaskManagementViewModel(helpTaskRepository: mockRepository)
        viewModel.isLoading = true

        // When: TaskManagementView を生成
        let view = TaskManagementView(viewModel: viewModel)

        // Then: ローディング中でもバナー広告が表示される
        XCTAssertNoThrow(try view.inspect().find(BannerAdView.self))
    }
}

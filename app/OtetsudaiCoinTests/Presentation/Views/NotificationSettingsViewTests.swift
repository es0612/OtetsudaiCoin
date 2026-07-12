import XCTest
import SwiftUI
@testable import OtetsudaiCoin

@MainActor
final class NotificationSettingsViewTests: XCTestCase {
    private var mockReminderService: MockReminderNotificationService!
    private var mockPaymentReminderService: MockPaymentReminderNotificationService!
    private var viewModel: NotificationSettingsViewModel!
    private var paymentViewModel: PaymentReminderNotificationSettingsViewModel!

    override func setUp() {
        super.setUp()
        mockReminderService = MockReminderNotificationService()
        mockPaymentReminderService = MockPaymentReminderNotificationService()
        viewModel = NotificationSettingsViewModel(service: mockReminderService)
        paymentViewModel = PaymentReminderNotificationSettingsViewModel(service: mockPaymentReminderService)
    }

    override func tearDown() {
        paymentViewModel = nil
        viewModel = nil
        mockPaymentReminderService = nil
        mockReminderService = nil
        super.tearDown()
    }

    /// NotificationSettingsView がクラッシュなく初期化できることを確認 (smoke test)。
    /// ViewInspector は Form + Toggle + DatePicker + .commonAlerts (chained .alert) の
    /// 組み合わせを深く traverse できない可能性がある (既知制約、CLAUDE.md 参照) ため、
    /// UI 構造の structural test は行わず、ロジックは ViewModel テストで網羅する (Issue #144)。
    func test_notificationSettingsView_initializes_withoutCrash() {
        _ = NotificationSettingsView(viewModel: viewModel, paymentViewModel: paymentViewModel)
    }

    /// errorMessage がセットされた状態でも View の初期化がクラッシュしないことを確認。
    /// .commonAlerts の isPresented バインディングが errorMessage の有無で正しく分岐できることの
    /// 間接的な担保（alert 表示状態自体は ViewInspector の制約で structural test 不可）。
    func test_notificationSettingsView_initializes_withoutCrash_whenErrorMessagePresent() async {
        mockReminderService.authorizationResult = true
        mockReminderService.scheduleDailyError = NSError(domain: "test", code: 1)
        await viewModel.toggleNotification(enabled: true)
        XCTAssertNotNil(viewModel.errorMessage)

        _ = NotificationSettingsView(viewModel: viewModel, paymentViewModel: paymentViewModel)
    }
}

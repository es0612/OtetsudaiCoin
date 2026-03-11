import XCTest
@testable import OtetsudaiCoin

/// ViewModel / Utils のローカライズされたメッセージ出力を検証するテスト
///
/// String(localized:) でラップされた文字列が、日本語ロケール（開発言語）で
/// 正しい日本語テキストを返すことを確認する。
final class LocalizedMessageTests: XCTestCase {

    // MARK: - ErrorMessageConverter テスト

    func testCoreDataDiskErrorReturnsLocalizedMessage() {
        // Given: ディスク容量不足を示す Core Data エラー
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "NSCocoaErrorDomain disk space full"]
        )

        // When: ユーザーフレンドリーメッセージに変換する
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then: ローカライズされた日本語メッセージが返ること
        XCTAssertEqual(message, String(localized: "ストレージ容量が不足しています。デバイスの空き容量を確保してください。"))
    }

    func testCoreDataPermissionErrorReturnsLocalizedMessage() {
        // Given: アクセス拒否を示す Core Data エラー
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "NSCocoaErrorDomain permission denied"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "データベースへのアクセスが拒否されました。アプリを再起動してください。"))
    }

    func testCoreDataCorruptErrorReturnsLocalizedMessage() {
        // Given: データベース破損を示す Core Data エラー
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "NSCocoaErrorDomain corrupt data"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "データベースに問題が発生しました。アプリを再起動してください。"))
    }

    func testCoreDataTimeoutErrorReturnsLocalizedMessage() {
        // Given: タイムアウトを示す Core Data エラー
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "NSCocoaErrorDomain timeout occurred"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "処理に時間がかかりすぎています。しばらく待ってから再度お試しください。"))
    }

    func testCoreDataGenericErrorReturnsLocalizedMessage() {
        // Given: 一般的な Core Data エラー
        let error = NSError(
            domain: "NSCocoaErrorDomain",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "NSCocoaErrorDomain generic error"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "データベースエラーが発生しました。アプリを再起動してください。"))
    }

    func testNetworkOfflineErrorReturnsLocalizedMessage() {
        // Given: オフラインを示すネットワークエラー
        let error = NSError(
            domain: "NSURLErrorDomain",
            code: -1009,
            userInfo: [NSLocalizedDescriptionKey: "NSURLErrorDomain not connected to internet"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "インターネット接続を確認してください。"))
    }

    func testNetworkTimeoutErrorReturnsLocalizedMessage() {
        // Given: タイムアウトを示すネットワークエラー
        let error = NSError(
            domain: "NSURLErrorDomain",
            code: -1001,
            userInfo: [NSLocalizedDescriptionKey: "NSURLErrorDomain timeout occurred"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "接続がタイムアウトしました。しばらく待ってから再度お試しください。"))
    }

    func testNetworkServerErrorReturnsLocalizedMessage() {
        // Given: サーバーエラーを示すネットワークエラー
        let error = NSError(
            domain: "NSURLErrorDomain",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "NSURLErrorDomain server error"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "サーバーに接続できません。しばらく待ってから再度お試しください。"))
    }

    func testNetworkGenericErrorReturnsLocalizedMessage() {
        // Given: 一般的なネットワークエラー
        let error = NSError(
            domain: "NSURLErrorDomain",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "NSURLErrorDomain unknown error"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "ネットワークエラーが発生しました。接続を確認してください。"))
    }

    func testFileSystemNoSpaceErrorReturnsLocalizedMessage() {
        // Given: 容量不足を示すファイルシステムエラー
        let error = NSError(
            domain: "NSPOSIXErrorDomain",
            code: 28,
            userInfo: [NSLocalizedDescriptionKey: "NSPOSIXErrorDomain no space left"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "ストレージ容量が不足しています。デバイスの空き容量を確保してください。"))
    }

    func testFileSystemPermissionDeniedErrorReturnsLocalizedMessage() {
        // Given: 権限拒否を示すファイルシステムエラー
        let error = NSError(
            domain: "NSPOSIXErrorDomain",
            code: 13,
            userInfo: [NSLocalizedDescriptionKey: "NSPOSIXErrorDomain permission denied"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "ファイルへのアクセスが拒否されました。アプリを再起動してください。"))
    }

    func testFileSystemFileNotFoundErrorReturnsLocalizedMessage() {
        // Given: ファイル不在を示すファイルシステムエラー
        let error = NSError(
            domain: "NSPOSIXErrorDomain",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "NSPOSIXErrorDomain file not found"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "必要なファイルが見つかりません。アプリを再インストールしてください。"))
    }

    func testFileSystemGenericErrorReturnsLocalizedMessage() {
        // Given: 一般的なファイルシステムエラー
        let error = NSError(
            domain: "NSPOSIXErrorDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "NSPOSIXErrorDomain generic error"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "ファイルシステムエラーが発生しました。アプリを再起動してください。"))
    }

    func testCommonInvalidDataErrorReturnsLocalizedMessage() {
        // Given: 無効データを示す一般エラー
        let error = NSError(
            domain: "AppError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "invalid format"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "入力データに問題があります。もう一度お試しください。"))
    }

    func testCommonCancelledErrorReturnsLocalizedMessage() {
        // Given: キャンセルを示す一般エラー
        let error = NSError(
            domain: "AppError",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "operation cancelled"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "処理がキャンセルされました。"))
    }

    func testCommonMemoryErrorReturnsLocalizedMessage() {
        // Given: メモリ不足を示す一般エラー
        let error = NSError(
            domain: "AppError",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "memory allocation failed"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "メモリが不足しています。他のアプリを終了してから再度お試しください。"))
    }

    func testCommonDuplicateErrorReturnsLocalizedMessage() {
        // Given: 重複を示す一般エラー
        let error = NSError(
            domain: "AppError",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "duplicate entry found"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "同じデータが既に存在します。"))
    }

    func testCommonTechnicalErrorReturnsLocalizedFallback() {
        // Given: 技術的な用語を含むエラー
        let error = NSError(
            domain: "AppError",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "fatal runtime exception occurred"]
        )

        // When
        let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)

        // Then
        XCTAssertEqual(message, String(localized: "予期しないエラーが発生しました。アプリを再起動してください。"))
    }

    // MARK: - PersistenceError テスト

    func testPersistenceErrorStoreLoadingFailedReturnsLocalizedDescription() {
        // Given: ストア読み込み失敗エラー
        let underlyingError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "test error"])
        let error = PersistenceError.storeLoadingFailed(underlyingError)

        // When: ローカライズされた説明を取得する
        let description = error.errorDescription

        // Then: ローカライズされたエラー説明を含むこと
        XCTAssertNotNil(description)
        let expectedPrefix = String(localized: "データベースの読み込みに失敗しました")
        XCTAssertTrue(description!.contains(expectedPrefix))
    }

    func testPersistenceErrorContextSaveFailedReturnsLocalizedDescription() {
        // Given: コンテキスト保存失敗エラー
        let underlyingError = NSError(domain: "TestDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "save error"])
        let error = PersistenceError.contextSaveFailed(underlyingError)

        // When
        let description = error.errorDescription

        // Then
        XCTAssertNotNil(description)
        let expectedPrefix = String(localized: "データの保存に失敗しました")
        XCTAssertTrue(description!.contains(expectedPrefix))
    }

    // MARK: - MonthlyRecord ローカライズテスト

    func testMonthlyRecordPaymentStatusTextUnpaid() {
        // Given: 未支払いの月次記録
        let record = MonthlyRecord(
            month: 6,
            year: 2025,
            helpRecords: [],
            allowanceAmount: 100,
            paymentRecord: nil,
            totalRecords: 0,
            isUnpaid: true,
            unpaidAmount: 100
        )

        // When: 支払いステータステキストを取得する
        let statusText = record.paymentStatusText

        // Then: ローカライズされた「未支払い」が返ること
        XCTAssertEqual(statusText, String(localized: "未支払い"))
    }

    func testMonthlyRecordPaymentStatusTextPartiallyPaid() {
        // Given: 一部支払い済みの月次記録
        let payment = AllowancePayment(
            id: UUID(),
            childId: UUID(),
            amount: 50,
            month: 6,
            year: 2025,
            paidAt: Date(),
            note: nil
        )
        let record = MonthlyRecord(
            month: 6,
            year: 2025,
            helpRecords: [],
            allowanceAmount: 100,
            paymentRecord: payment,
            totalRecords: 0,
            isUnpaid: false,
            unpaidAmount: 50
        )

        // When
        let statusText = record.paymentStatusText

        // Then: ローカライズされた「一部支払い済み」が返ること
        XCTAssertEqual(statusText, String(localized: "一部支払い済み"))
    }

    func testMonthlyRecordPaymentStatusTextPaid() {
        // Given: 全額支払い済みの月次記録
        let payment = AllowancePayment(
            id: UUID(),
            childId: UUID(),
            amount: 100,
            month: 6,
            year: 2025,
            paidAt: Date(),
            note: nil
        )
        let record = MonthlyRecord(
            month: 6,
            year: 2025,
            helpRecords: [],
            allowanceAmount: 100,
            paymentRecord: payment,
            totalRecords: 0,
            isUnpaid: false,
            unpaidAmount: 0
        )

        // When
        let statusText = record.paymentStatusText

        // Then: ローカライズされた「支払い済み」が返ること
        XCTAssertEqual(statusText, String(localized: "支払い済み"))
    }

    // MARK: - RecordViewModel ローカライズテスト

    @MainActor
    func testRecordViewModelErrorMessageWithoutChild() {
        // Given: 子供が未選択の RecordViewModel
        let viewModel = RecordViewModel(
            childRepository: MockChildRepository(),
            helpTaskRepository: MockHelpTaskRepository(),
            helpRecordRepository: MockHelpRecordRepository()
        )
        let task = HelpTask(id: UUID(), name: "テスト", isActive: true)
        viewModel.selectTask(task)

        // When: お手伝い記録を試みる
        viewModel.recordHelp()

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "お子様を選択してください"))
    }

    @MainActor
    func testRecordViewModelErrorMessageWithoutTask() {
        // Given: タスクが未選択の RecordViewModel
        let viewModel = RecordViewModel(
            childRepository: MockChildRepository(),
            helpTaskRepository: MockHelpTaskRepository(),
            helpRecordRepository: MockHelpRecordRepository()
        )
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        viewModel.selectChild(child)

        // When: お手伝い記録を試みる
        viewModel.recordHelp()

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "お手伝いタスクを選択してください"))
    }

    // MARK: - TaskManagementViewModel ローカライズテスト

    @MainActor
    func testTaskManagementViewModelEmptyNameError() async {
        // Given: TaskManagementViewModel
        let viewModel = TaskManagementViewModel(helpTaskRepository: MockHelpTaskRepository())

        // When: 空の名前でタスクを追加する
        await viewModel.addTask(name: "  ")

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "タスク名を入力してください"))
    }

    @MainActor
    func testTaskManagementViewModelInvalidCoinRateError() async {
        // Given: TaskManagementViewModel
        let viewModel = TaskManagementViewModel(helpTaskRepository: MockHelpTaskRepository())

        // When: 0以下のコイン単価でタスクを追加する
        await viewModel.addTask(name: "テストタスク", coinRate: 0)

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "コイン単価は1以上で入力してください"))
    }

    @MainActor
    func testTaskManagementViewModelDuplicateNameError() async {
        // Given: 既にタスクが存在する TaskManagementViewModel
        let mockRepo = MockHelpTaskRepository()
        let existingTask = HelpTask(id: UUID(), name: "洗い物", isActive: true)
        mockRepo.tasks = [existingTask]

        let viewModel = TaskManagementViewModel(helpTaskRepository: mockRepo)
        await viewModel.loadTasks()

        // When: 同じ名前のタスクを追加する
        await viewModel.addTask(name: "洗い物")

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "同じ名前のタスクが既に存在します"))
    }

    // MARK: - HomeViewModel ローカライズテスト

    @MainActor
    func testHomeViewModelPayWithoutChildError() {
        // Given: 子供が未選択の HomeViewModel
        let viewModel = HomeViewModel(
            childRepository: MockChildRepository(),
            helpRecordRepository: MockHelpRecordRepository(),
            helpTaskRepository: MockHelpTaskRepository(),
            allowanceCalculator: MockAllowanceCalculator(),
            allowancePaymentRepository: MockAllowancePaymentRepository()
        )

        // When: お小遣い支払いを試みる
        viewModel.payMonthlyAllowance()

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "子供が選択されていません"))
    }

    @MainActor
    func testHomeViewModelRecordPaymentWithoutChildError() {
        // Given: 子供が未選択の HomeViewModel
        let viewModel = HomeViewModel(
            childRepository: MockChildRepository(),
            helpRecordRepository: MockHelpRecordRepository(),
            helpTaskRepository: MockHelpTaskRepository(),
            allowanceCalculator: MockAllowanceCalculator(),
            allowancePaymentRepository: MockAllowancePaymentRepository()
        )

        // When: 支払い記録を試みる
        viewModel.recordAllowancePayment(amount: 100)

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "子供が選択されていません"))
    }

    // MARK: - ChildManagementViewModel ローカライズテスト

    @MainActor
    func testChildManagementViewModelInvalidDataError() async {
        // Given: ChildManagementViewModel
        let viewModel = ChildManagementViewModel(childRepository: MockChildRepository())

        // When: 無効なデータで子供を追加する
        await viewModel.addChild(name: "", themeColor: "#FF5733")

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "入力データが無効です"))
    }

    @MainActor
    func testChildManagementViewModelDuplicateNameError() async {
        // Given: 既に子供が登録されている ChildManagementViewModel
        let mockRepo = MockChildRepository()
        let existingChild = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        mockRepo.children = [existingChild]

        let viewModel = ChildManagementViewModel(childRepository: mockRepo)
        await viewModel.loadChildren()

        // When: 同じ名前の子供を追加する
        await viewModel.addChild(name: "太郎", themeColor: "#33FF57")

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "同じ名前の子供が既に登録されています"))
    }

    @MainActor
    func testChildManagementViewModelDeleteNotFoundError() async {
        // Given: 空の ChildManagementViewModel
        let viewModel = ChildManagementViewModel(childRepository: MockChildRepository())

        // When: 存在しない子供を削除しようとする
        await viewModel.deleteChild(id: UUID())

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "削除対象の子供が見つかりません"))
    }

    // MARK: - HelpRecordEditViewModel ローカライズテスト

    @MainActor
    func testHelpRecordEditViewModelSaveWithoutTaskError() {
        // Given: タスクが未選択の HelpRecordEditViewModel
        let record = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: Date())
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let viewModel = HelpRecordEditViewModel(
            helpRecord: record,
            child: child,
            helpRecordRepository: MockHelpRecordRepository(),
            helpTaskRepository: MockHelpTaskRepository()
        )

        // When: タスク未選択のまま保存を試みる
        viewModel.saveChanges()

        // Then: ローカライズされたエラーメッセージが設定されること
        XCTAssertEqual(viewModel.errorMessage, String(localized: "お手伝いタスクを選択してください"))
    }
}

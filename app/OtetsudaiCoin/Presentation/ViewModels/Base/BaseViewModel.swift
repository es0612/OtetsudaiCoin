import Foundation
import Combine

@Observable
class BaseViewModel {
    // 直接的な状態プロパティ（@Observableで適切に追跡される）
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?
    
    var cancellables = Set<AnyCancellable>()
    var loadDataTask: Task<Void, Never>?
    
    init() {
        setupNotificationListeners()
    }
    
    func setupNotificationListeners() {
        // 子クラスでオーバーライド
    }
    
    func clearMessages() {
        DebugLogger.debug("BaseViewModel.clearMessages: Clearing all messages")
        errorMessage = nil
        successMessage = nil
    }
    
    func clearErrorMessage() {
        DebugLogger.debug("BaseViewModel.clearErrorMessage: Clearing error message")
        errorMessage = nil
    }
    
    func clearSuccessMessage() {
        DebugLogger.debug("BaseViewModel.clearSuccessMessage: Clearing success message")
        successMessage = nil
    }
    
    @MainActor
    func setLoading(_ loading: Bool) {
        DebugLogger.logViewModelState(
            viewModel: String(describing: type(of: self)),
            state: "setLoading",
            details: "Loading: \(loading) (previous: \(isLoading))"
        )
        isLoading = loading
        if loading {
            errorMessage = nil
            DebugLogger.debug("BaseViewModel: Cleared error message due to loading start")
        }
    }
    
    @MainActor
    func setError(_ message: String) {
        DebugLogger.logViewModelState(
            viewModel: String(describing: type(of: self)),
            state: "setError",
            details: "Error: \(message)"
        )
        isLoading = false
        errorMessage = message
        successMessage = nil
    }
    
    @MainActor
    func setSuccess(_ message: String) {
        DebugLogger.logViewModelState(
            viewModel: String(describing: type(of: self)),
            state: "setSuccess",
            details: "Success: \(message)"
        )
        isLoading = false
        successMessage = message
        errorMessage = nil
    }
    
    
    func cancelLoadDataTask() {
        if loadDataTask != nil {
            DebugLogger.logViewModelState(
                viewModel: String(describing: type(of: self)),
                state: "cancelLoadDataTask",
                details: "Cancelling existing task"
            )
            loadDataTask?.cancel()
            loadDataTask = nil
        }
    }
}
import Foundation
import Combine

@Observable
class BaseViewModel {
    var viewState = ViewState()
    var cancellables = Set<AnyCancellable>()
    var loadDataTask: Task<Void, Never>?
    
    var isLoading: Bool { viewState.isLoading }
    var errorMessage: String? { viewState.errorMessage }
    var successMessage: String? { viewState.successMessage }
    
    init() {
        setupNotificationListeners()
    }
    
    func setupNotificationListeners() {
        // 子クラスでオーバーライド
    }
    
    func clearMessages() {
        viewState.clear()
    }
    
    func clearErrorMessage() {
        viewState.clearOnlyError()
    }
    
    func clearSuccessMessage() {
        viewState.clearOnlySuccess()
    }
    
    func setLoading(_ loading: Bool) {
        DebugLogger.logViewModelState(
            viewModel: String(describing: type(of: self)),
            state: "setLoading",
            details: "Loading: \(loading)"
        )
        viewState.setLoading(loading)
    }
    
    func setError(_ message: String) {
        DebugLogger.logViewModelState(
            viewModel: String(describing: type(of: self)),
            state: "setError",
            details: "Error: \(message)"
        )
        viewState.setError(message)
    }
    
    func setSuccess(_ message: String) {
        DebugLogger.logViewModelState(
            viewModel: String(describing: type(of: self)),
            state: "setSuccess",
            details: "Success: \(message)"
        )
        viewState.setSuccess(message)
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
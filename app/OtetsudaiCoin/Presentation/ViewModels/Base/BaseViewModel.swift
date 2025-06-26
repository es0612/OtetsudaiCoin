import Foundation
import Combine

@Observable
class BaseViewModel {
    var viewState = ViewState()
    var cancellables = Set<AnyCancellable>()
    
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
        viewState.setLoading(loading)
    }
    
    func setError(_ message: String) {
        viewState.setError(message)
    }
    
    func setSuccess(_ message: String) {
        viewState.setSuccess(message)
    }
}
import Foundation

struct ViewState {
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?
    
    mutating func setLoading(_ loading: Bool) {
        DebugLogger.debug("ViewState.setLoading: \(loading) (previous: \(isLoading))")
        isLoading = loading
        if loading {
            errorMessage = nil
            DebugLogger.debug("ViewState: Cleared error message due to loading start")
        }
    }
    
    mutating func setError(_ message: String) {
        DebugLogger.debug("ViewState.setError: \(message) (was loading: \(isLoading))")
        isLoading = false
        errorMessage = message
        successMessage = nil
    }
    
    mutating func setSuccess(_ message: String) {
        DebugLogger.debug("ViewState.setSuccess: \(message) (was loading: \(isLoading))")
        isLoading = false
        successMessage = message
        errorMessage = nil
    }
    
    mutating func clear() {
        DebugLogger.debug("ViewState.clear: Clearing all messages")
        errorMessage = nil
        successMessage = nil
    }
    
    mutating func clearOnlyError() {
        DebugLogger.debug("ViewState.clearOnlyError: Clearing error message")
        errorMessage = nil
    }
    
    mutating func clearOnlySuccess() {
        DebugLogger.debug("ViewState.clearOnlySuccess: Clearing success message")
        successMessage = nil
    }
}
import Foundation

struct ViewState {
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?
    
    mutating func setLoading(_ loading: Bool) {
        isLoading = loading
        if loading {
            errorMessage = nil
        }
    }
    
    mutating func setError(_ message: String) {
        isLoading = false
        errorMessage = message
        successMessage = nil
    }
    
    mutating func setSuccess(_ message: String) {
        isLoading = false
        successMessage = message
        errorMessage = nil
    }
    
    mutating func clear() {
        errorMessage = nil
        successMessage = nil
    }
    
    mutating func clearOnlyError() {
        errorMessage = nil
    }
    
    mutating func clearOnlySuccess() {
        successMessage = nil
    }
}
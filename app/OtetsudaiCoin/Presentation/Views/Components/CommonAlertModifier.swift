import SwiftUI

struct CommonAlertModifier: ViewModifier {
    let errorMessage: String?
    let successMessage: String?
    let onErrorDismiss: () -> Void
    let onSuccessDismiss: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { onErrorDismiss() }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("成功", isPresented: .constant(successMessage != nil)) {
                Button("OK") { onSuccessDismiss() }
            } message: {
                Text(successMessage ?? "")
            }
    }
}

extension View {
    func commonAlerts(
        errorMessage: String?,
        successMessage: String?,
        onErrorDismiss: @escaping () -> Void = {},
        onSuccessDismiss: @escaping () -> Void = {}
    ) -> some View {
        modifier(CommonAlertModifier(
            errorMessage: errorMessage,
            successMessage: successMessage,
            onErrorDismiss: onErrorDismiss,
            onSuccessDismiss: onSuccessDismiss
        ))
    }
}
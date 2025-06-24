import SwiftUI

struct CommonAlertModifier: ViewModifier {
    let viewState: ViewState
    let onErrorDismiss: () -> Void
    let onSuccessDismiss: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("エラー", isPresented: .constant(viewState.errorMessage != nil)) {
                Button("OK") { onErrorDismiss() }
            } message: {
                Text(viewState.errorMessage ?? "")
            }
            .alert("成功", isPresented: .constant(viewState.successMessage != nil)) {
                Button("OK") { onSuccessDismiss() }
            } message: {
                Text(viewState.successMessage ?? "")
            }
    }
}

extension View {
    func commonAlerts(
        viewState: ViewState,
        onErrorDismiss: @escaping () -> Void = {},
        onSuccessDismiss: @escaping () -> Void = {}
    ) -> some View {
        modifier(CommonAlertModifier(
            viewState: viewState,
            onErrorDismiss: onErrorDismiss,
            onSuccessDismiss: onSuccessDismiss
        ))
    }
}
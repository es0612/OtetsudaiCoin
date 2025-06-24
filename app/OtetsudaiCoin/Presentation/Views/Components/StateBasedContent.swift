import SwiftUI

struct StateBasedContent<Content: View>: View {
    let viewState: ViewState
    let onRetry: (() -> Void)?
    @ViewBuilder let content: () -> Content
    
    init(
        viewState: ViewState,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.viewState = viewState
        self.onRetry = onRetry
        self.content = content
    }
    
    var body: some View {
        if viewState.isLoading {
            LoadingView()
        } else if let errorMessage = viewState.errorMessage {
            ErrorView(message: errorMessage, onRetry: onRetry)
        } else {
            content()
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("読み込み中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding()
            
            if let onRetry = onRetry {
                Button("再試行") {
                    onRetry()
                }
                .primaryGradientButton()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
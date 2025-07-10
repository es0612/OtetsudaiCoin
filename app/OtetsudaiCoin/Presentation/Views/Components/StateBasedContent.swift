import SwiftUI

struct StateBasedContent<Content: View, LoadingContent: View>: View {
    let viewState: ViewState
    let onRetry: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let loadingContent: () -> LoadingContent
    
    init(
        viewState: ViewState,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) where LoadingContent == LoadingView {
        self.viewState = viewState
        self.onRetry = onRetry
        self.loadingContent = { LoadingView() }
        self.content = content
    }
    
    init(
        viewState: ViewState,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.viewState = viewState
        self.onRetry = onRetry
        self.loadingContent = loadingContent
        self.content = content
    }
    
    var body: some View {
        if viewState.isLoading {
            loadingContent()
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
                .tint(AccessibilityColors.primaryBlue)
            Text("読み込み中...")
                .foregroundColor(AccessibilityColors.textSecondary)
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
                .foregroundColor(AccessibilityColors.errorRed)
            
            Text(message)
                .foregroundColor(AccessibilityColors.textPrimary)
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
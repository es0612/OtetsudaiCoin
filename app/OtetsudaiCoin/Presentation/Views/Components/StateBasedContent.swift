import SwiftUI

struct StateBasedContent<Content: View, LoadingContent: View>: View {
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: (() -> Void)?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let loadingContent: () -> LoadingContent
    
    init(
        isLoading: Bool,
        errorMessage: String? = nil,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) where LoadingContent == LoadingView {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.loadingContent = { LoadingView() }
        self.content = content
    }
    
    init(
        isLoading: Bool,
        errorMessage: String? = nil,
        onRetry: (() -> Void)? = nil,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onRetry = onRetry
        self.loadingContent = loadingContent
        self.content = content
    }
    
    var body: some View {
        if isLoading {
            loadingContent()
        } else if let errorMessage = errorMessage {
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
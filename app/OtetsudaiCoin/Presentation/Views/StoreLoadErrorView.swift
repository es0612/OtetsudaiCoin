import SwiftUI

/// Core Data ストアの読み込みに失敗したときに、アプリ全体（TabView）の代わりに表示する画面（Issue #131）。
///
/// ストアが attach されず全データが空に見える状態を正しくユーザーへ伝える。
/// 破壊的な自動復旧は行わず、アプリの再起動を促す（iOS はアプリ自身を再起動できないため
/// ボタンではなく案内文のみ）。既存の `ErrorView`（再試行ボタン前提の汎用エラー）とは
/// 用途が異なる（ストアは再試行で開き直せない）ため専用 View にしている。
struct StoreLoadErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(AccessibilityColors.errorRed)
                .accessibilityHidden(true)  // タイトルテキストが同じ意味を伝えるため装飾扱い（VoiceOver は読まない）

            Text("データを読み込めませんでした")
                .font(.headline)
                .foregroundColor(AccessibilityColors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)  // VoiceOver の見出しナビでタイトルへ飛べるようにする

            Text("アプリをいったん完全に終了してから、もう一度開いてください。問題が解決しない場合は、お手数ですがサポートまでご連絡ください。")
                .font(.subheadline)
                .foregroundColor(AccessibilityColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#if DEBUG
#Preview {
    StoreLoadErrorView()
}
#endif

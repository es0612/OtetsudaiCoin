import SwiftUI

/// お手伝い管理画面のアクションボタン群（タスク追加 / よく使う順並べ替え）。
///
/// TaskManagementView 本体は NavigationStack + List + BannerAdView(UIViewRepresentable) を
/// 含み ViewInspector で traverse 不可のため、テスト可能性のためにボタンを component 分離する
/// (#130-④、#74 RecordButtonBar と同じ path)。
/// ボタンは Label 化して VoiceOver がアイコン名でなくタイトルを読むようにする (#130-④)。
struct TaskListActionButtons: View {
    let canSortByFrequency: Bool
    let onAdd: () -> Void
    let onSortByFrequency: () -> Void

    var body: some View {
        Group {
            Button(action: onAdd) {
                Label("新しいタスクを追加", systemImage: "plus.circle.fill")
            }
            .primaryGradientButton()

            Button(action: onSortByFrequency) {
                Label("よく使う順に並べ替え", systemImage: "arrow.up.arrow.down")
            }
            .disabled(!canSortByFrequency)
        }
    }
}

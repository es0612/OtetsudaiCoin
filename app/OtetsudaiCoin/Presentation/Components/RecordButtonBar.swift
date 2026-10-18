import SwiftUI

/// 画面下部固定の記録ボタン領域。選択状態の表示 + 記録ボタンを担当。
/// #74: ViewInspector が RecordView 本体 (NavigationStack + ScrollView + BannerAdView の組み合わせ) を
/// 深く traverse できないため、独立 component に切り出して structural test を可能にする。
struct RecordButtonBar: View {
    @Bindable var viewModel: RecordViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // AX 最大では説明文が 4 行に折り返し (「10コイン」も「10コイ/ン」に折れる)、バーが画面の約 45% を
    // 占めてスクロールできる高さが約 420pt しか残らなかった (#265)。AX サイズのときだけ説明文を出さず
    // ボタンだけにする。選んだ内容はカード側 (✓ と枠の色) で分かり、消した説明文は VoiceOver のヒント
    // (recordButtonHint) で読み上げる。既定サイズは今までどおり。
    static func showsSelectionStatus(isAccessibilitySize: Bool) -> Bool {
        !isAccessibilitySize
    }

    var body: some View {
        VStack(spacing: 8) {
            if Self.showsSelectionStatus(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) {
                selectionStatusView
            }

            Button(action: {
                if viewModel.isBulkMode {
                    viewModel.recordBulkHelp()
                } else {
                    viewModel.recordHelp()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(recordButtonLabel)
                }
            }
            .successButton()
            .disabled(recordButtonDisabled)
            .accessibilityHint(recordButtonHint(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) ?? "")
            .accessibilityIdentifier("record_button")
        }
    }

    @ViewBuilder
    private var selectionStatusView: some View {
        if viewModel.isBulkMode {
            bulkSummaryView
        } else if let selectedChild = viewModel.selectedChild, let selectedTask = viewModel.selectedTask {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(selectedChild.name)さんの「\(selectedTask.displayName)」")
                    .appFont(.captionText)
                    .foregroundColor(.secondary)
                Text("\(selectedTask.coinRate)コイン")
                    .appFont(.captionText)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)
                Text("お手伝いする人とタスクを選んでください")
                    .appFont(.captionText)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }

    var recordButtonLabel: String {
        if viewModel.isBulkMode {
            // 文字列補間で `String.LocalizationValue` を生成すると、xcstrings の plural variations が
            // count 値に応じて one / other 自動選択される。String(format:) は variations を bypass するため使わない。
            let count = viewModel.selectedTaskIds.count
            return String(localized: "\(count) 件をまとめて記録する")
        } else {
            return String(localized: "記録する")
        }
    }

    /// AX サイズで画面から消した説明文 (押せない理由・誰の何コインか・一括の合計) を、
    /// レイアウトを使わない VoiceOver のヒントとして返す (#265)。説明文が画面に出ているときは nil。
    func recordButtonHint(isAccessibilitySize: Bool) -> String? {
        guard !Self.showsSelectionStatus(isAccessibilitySize: isAccessibilitySize) else { return nil }
        if viewModel.isBulkMode {
            return String(format: String(localized: "選択中 %lld 件 / 計 %lld コイン"), viewModel.selectedTaskIds.count, bulkTotalCoins)
        } else if let selectedChild = viewModel.selectedChild, let selectedTask = viewModel.selectedTask {
            return String(localized: "\(selectedChild.name)さんの「\(selectedTask.displayName)」") + " "
                + String(localized: "\(selectedTask.coinRate)コイン")
        } else {
            return String(localized: "お手伝いする人とタスクを選んでください")
        }
    }

    private var bulkTotalCoins: Int {
        let tasksById = Dictionary(uniqueKeysWithValues: viewModel.availableTasks.map { ($0.id, $0) })
        return viewModel.selectedTaskIds.reduce(0) { acc, id in
            acc + (tasksById[id]?.coinRate ?? 0)
        }
    }

    var recordButtonDisabled: Bool {
        if viewModel.isBulkMode {
            return viewModel.selectedChild == nil || viewModel.selectedTaskIds.isEmpty
        } else {
            return viewModel.selectedChild == nil || viewModel.selectedTask == nil
        }
    }

    private var bulkSummaryView: some View {
        let count = viewModel.selectedTaskIds.count
        let totalCoins = bulkTotalCoins
        let format = String(localized: "選択中 %lld 件 / 計 %lld コイン")
        return HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(String(format: format, count, totalCoins))
                .appFont(.captionText)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

import SwiftUI

struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    var isBulkMode: Bool = false
    var existingCount: Int = 0
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                taskIcon
                taskTitle
                coinInfo
                existingCountRow
                selectionIndicator
            }
            .padding()
            .frame(height: 150)
            .background(cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    @ViewBuilder
    private var existingCountRow: some View {
        if existingCount >= 1 {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
                Text(existingCountText)
                    .appFont(.captionText)
                    .foregroundColor(.gray.opacity(0.7))
                    .accessibilityIdentifier("existing_count_label")
            }
        } else {
            EmptyView()
        }
    }

    private var existingCountText: String {
        // 文字列補間で xcstrings の plural variations を利用する。
        // String(format:) は variations を bypass する既知罠 (CLAUDE.md i18n 節)。
        let count = existingCount
        return String(localized: "すでに \(count) 件記録済み")
    }

    private var taskIcon: some View {
        ZStack {
            Circle()
                .fill(isSelected ? .blue : .gray.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: "hands.sparkles")
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
        }
    }

    private var taskTitle: some View {
        Text(task.displayName)
            .appFont(.cardTitle)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundColor(AccessibilityColors.textPrimary)
            .lineLimit(2)
    }

    private var coinInfo: some View {
        Text("\(task.coinRate)コイン")
            .appFont(.captionText)
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? .blue : .secondary)
    }

    private var selectionIndicator: some View {
        Group {
            if isBulkMode {
                bulkSelectionIndicator
            } else if isSelected {
                selectedIndicator
            } else {
                unselectedIndicator
            }
        }
    }

    private var bulkSelectionIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
            Text(isSelected ? "選択中" : "選択")
                .appFont(.captionText)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .blue : .gray.opacity(0.7))
        }
    }

    private var selectedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
            Text("選択中")
                .appFont(.captionText)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }

    private var unselectedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundColor(.gray.opacity(0.5))
            Text("タップして選択")
                .appFont(.captionText)
                .foregroundColor(.gray.opacity(0.7))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.large)
            .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
    }
}

import SwiftUI

struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    var isBulkMode: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                taskIcon
                taskTitle
                coinInfo
                selectionIndicator
            }
            .padding()
            .frame(height: 140)
            .background(cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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
        Text(task.name)
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
        RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
    }
}

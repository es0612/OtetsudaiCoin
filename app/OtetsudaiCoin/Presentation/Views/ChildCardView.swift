import SwiftUI

struct ChildCardView: View {
    let child: Child
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeColor)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text(child.name)
                    .appFont(.captionText)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? themeColor : AccessibilityColors.textPrimary)
                
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("選択中")
                            .appFont(.captionText)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                } else {
                    Text("タップして選択")
                        .appFont(.captionText)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .padding()
            .frame(width: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeColor.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? themeColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityIdentifier("child_button")
    }
    
    private var themeColor: Color {
        Color(hex: child.themeColor) ?? .blue
    }
}
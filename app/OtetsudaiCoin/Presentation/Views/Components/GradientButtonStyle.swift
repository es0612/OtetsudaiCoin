import SwiftUI

// MARK: - グラデーションボタンスタイル

struct GradientButtonStyle: ButtonStyle {
    let colors: [Color]
    let cornerRadius: CGFloat
    let isDisabled: Bool
    
    init(colors: [Color] = [.blue, .purple], cornerRadius: CGFloat = 25, isDisabled: Bool = false) {
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isDisabled ? [.gray.opacity(0.6)] : colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(
                color: isDisabled ? .clear : colors.first?.opacity(0.4) ?? .clear,
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - プリセットスタイル

extension GradientButtonStyle {
    static let primary = GradientButtonStyle(colors: [.blue, .purple])
    static let success = GradientButtonStyle(colors: [.green, .blue])
    static let warning = GradientButtonStyle(colors: [.orange, .red])
    static let accent = GradientButtonStyle(colors: [.pink, .purple])
}

// MARK: - 便利なView Extension

extension View {
    func gradientButtonStyle(_ style: GradientButtonStyle = .primary, isDisabled: Bool = false) -> some View {
        self.buttonStyle(GradientButtonStyle(
            colors: style.colors,
            cornerRadius: style.cornerRadius,
            isDisabled: isDisabled
        ))
    }
    
    func primaryGradientButton(isDisabled: Bool = false) -> some View {
        self.gradientButtonStyle(.primary, isDisabled: isDisabled)
    }
    
    func successGradientButton(isDisabled: Bool = false) -> some View {
        self.gradientButtonStyle(.success, isDisabled: isDisabled)
    }
    
    func warningGradientButton(isDisabled: Bool = false) -> some View {
        self.gradientButtonStyle(.warning, isDisabled: isDisabled)
    }
    
    func accentGradientButton(isDisabled: Bool = false) -> some View {
        self.gradientButtonStyle(.accent, isDisabled: isDisabled)
    }
}

// MARK: - サブボタンスタイル（小さめのボタン用）

struct CompactGradientButtonStyle: ButtonStyle {
    let colors: [Color]
    let isDisabled: Bool
    
    init(colors: [Color] = [.blue, .purple], isDisabled: Bool = false) {
        self.colors = colors
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: isDisabled ? [.gray.opacity(0.6)] : colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(
                color: isDisabled ? .clear : colors.first?.opacity(0.3) ?? .clear,
                radius: configuration.isPressed ? 2 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func compactGradientButton(colors: [Color] = [.blue, .purple], isDisabled: Bool = false) -> some View {
        self.buttonStyle(CompactGradientButtonStyle(colors: colors, isDisabled: isDisabled))
    }
}
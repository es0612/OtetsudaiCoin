import SwiftUI

struct CoinAnimationView: View {
    @Binding var isVisible: Bool
    let coinValue: Int
    let themeColor: String
    
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0.0
    @State private var rotation: Double = 0.0
    @State private var yOffset: CGFloat = 0.0
    
    var body: some View {
        if isVisible {
            VStack(spacing: 8) {
                ZStack {
                    // コインの背景
                    Circle()
                        .fill(Color(hex: themeColor) ?? .yellow)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // コインのテキスト
                    VStack(spacing: 4) {
                        Text("\(coinValue)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("コイン")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)
                .rotationEffect(.degrees(rotation))
                .offset(y: yOffset)
                
                // "おめでとう！"メッセージ
                Text("おめでとう！")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: themeColor) ?? .yellow)
                    .opacity(opacity)
                    .scaleEffect(scale * 0.8)
            }
            .onAppear {
                withAnimation(.bouncy(duration: 0.8)) {
                    scale = 1.0
                    opacity = 1.0
                    rotation = 360.0
                }
                
                withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
                    yOffset = -20.0
                }
                
                // 自動で非表示にする
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        opacity = 0.0
                        scale = 0.8
                        yOffset = -50.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isVisible = false
                        resetAnimation()
                    }
                }
            }
        }
    }
    
    private func resetAnimation() {
        scale = 0.1
        opacity = 0.0
        rotation = 0.0
        yOffset = 0.0
    }
}
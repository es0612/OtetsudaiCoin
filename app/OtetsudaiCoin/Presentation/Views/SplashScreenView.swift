import SwiftUI

struct SplashScreenView: View {
    @State private var coinScale: CGFloat = 0.3
    @State private var coinRotation: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 30
    @State private var glowIntensity: Double = 0.3
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // 温かみのある2色グラデーション背景
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.8),
                    Color.yellow.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // メインコインアイコン
                ZStack {
                    // 柔らかい外側のグロー
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.yellow.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 60,
                                endRadius: 120
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(coinScale)
                        .opacity(glowIntensity)
                    
                    // メインコイン
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.yellow.opacity(0.95),
                                    Color.orange.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            // コインの中央アイコン
                            Image(systemName: "hands.sparkles")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        )
                        .scaleEffect(coinScale)
                        .rotationEffect(.degrees(coinRotation))
                        .shadow(
                            color: .orange.opacity(0.4),
                            radius: 8,
                            x: 0, y: 2
                        )
                }
                
                // アプリタイトル
                VStack(spacing: 16) {
                    Text("OtetsudaiCoin")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                        .opacity(titleOpacity)
                    
                    Text("お手伝いでコインを貯めよう！")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        .offset(y: subtitleOffset)
                        .opacity(titleOpacity)
                }
                
                Spacer()
                
                // シンプルなローディングインジケータ
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.7))
                                .frame(width: 8, height: 8)
                                .scaleEffect(coinScale > 0.8 ? 1.1 : 0.9)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever()
                                    .delay(Double(index) * 0.15),
                                    value: coinScale
                                )
                        }
                    }
                    
                    Text("読み込み中...")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(titleOpacity)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
            
            // 2.5秒後に完了
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    onComplete()
                }
            }
        }
    }
    
    private func startAnimations() {
        // コインのスケールアップ
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7, blendDuration: 0)) {
            coinScale = 1.0
        }
        
        // コインの穏やかな回転
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            coinRotation = 360
        }
        
        // グロー効果
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
            glowIntensity = 0.8
        }
        
        // タイトルのフェードイン
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            titleOpacity = 1.0
        }
        
        // サブタイトルのスライドイン
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8, blendDuration: 0).delay(0.6)) {
            subtitleOffset = 0
        }
    }
}

#Preview {
    SplashScreenView {
        print("Splash completed")
    }
}
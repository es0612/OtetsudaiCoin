import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var coinScale: CGFloat = 0.3
    @State private var coinRotation: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 50
    @State private var particleOffset: CGFloat = 0
    @State private var gradientAngle: Double = 0
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // 動的グラデーション背景
            AngularGradient(
                colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.pink.opacity(0.8),
                    Color.orange.opacity(0.6),
                    Color.yellow.opacity(0.8),
                    Color.blue.opacity(0.8)
                ],
                center: .center,
                startAngle: .degrees(gradientAngle),
                endAngle: .degrees(gradientAngle + 360)
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    gradientAngle = 360
                }
            }
            
            // パーティクル効果の背景
            particleBackground
            
            VStack(spacing: 32) {
                Spacer()
                
                // メインコインアイコン
                ZStack {
                    // 外側のリング
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 8
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(coinScale)
                        .opacity(isAnimating ? 1 : 0)
                    
                    // メインコイン
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.yellow.opacity(0.9),
                                    Color.orange.opacity(0.8),
                                    Color.yellow.opacity(0.7)
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            // コインの中央アイコン
                            Image(systemName: "hands.sparkles")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        )
                        .scaleEffect(coinScale)
                        .rotationEffect(.degrees(coinRotation))
                        .shadow(
                            color: .yellow.opacity(0.5),
                            radius: 20,
                            x: 0, y: 0
                        )
                    
                    // 光る効果
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 5,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .offset(x: -20, y: -20)
                        .scaleEffect(coinScale)
                        .opacity(isAnimating ? 0.7 : 0)
                }
                
                // アプリタイトル
                VStack(spacing: 16) {
                    Text("OtetsudaiCoin")
                        .font(.custom("", size: 42))
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.yellow.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
                        .opacity(titleOpacity)
                    
                    Text("お手伝いでコインを貯めよう！")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        .offset(y: subtitleOffset)
                        .opacity(titleOpacity)
                }
                
                Spacer()
                
                // ローディングインジケータ
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 12, height: 12)
                                .scaleEffect(isAnimating ? 1.2 : 0.8)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    
                    Text("読み込み中...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(titleOpacity)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
            
            // 3秒後に完了
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    onComplete()
                }
            }
        }
    }
    
    private var particleBackground: some View {
        ZStack {
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: CGFloat.random(in: 4...12), height: CGFloat.random(in: 4...12))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height) + particleOffset
                    )
                    .animation(
                        .linear(duration: Double.random(in: 3...6))
                        .repeatForever(autoreverses: false)
                        .delay(Double.random(in: 0...2)),
                        value: particleOffset
                    )
            }
        }
        .onAppear {
            particleOffset = -100
        }
    }
    
    private func startAnimations() {
        // コインのスケールアップ
        withAnimation(.spring(response: 1.2, dampingFraction: 0.6, blendDuration: 0)) {
            coinScale = 1.0
        }
        
        // コインの回転
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            coinRotation = 360
        }
        
        // タイトルのフェードイン
        withAnimation(.easeOut(duration: 1).delay(0.5)) {
            titleOpacity = 1.0
        }
        
        // サブタイトルのスライドイン
        withAnimation(.spring(response: 1, dampingFraction: 0.8, blendDuration: 0).delay(0.8)) {
            subtitleOffset = 0
        }
        
        // アニメーション状態の更新
        withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
            isAnimating = true
        }
    }
}

#Preview {
    SplashScreenView {
        print("Splash completed")
    }
}
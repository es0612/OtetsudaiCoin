import SwiftUI

struct SplashScreenView: View {
    @State private var iconScale: CGFloat = 0.3
    @State private var titleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 30
    @State private var glowIntensity: Double = 0.3
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // #151 ダークモード1: 新アイコン (#18) と同じクリーム / dark は暗い暖色 (黒にしない)
            LinearGradient(
                colors: [
                    AccessibilityColors.splashBackgroundTop,
                    AccessibilityColors.splashBackgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // メインアイコン: ホーム画面のアイコンと同じ絵を拡大して見せる
                Image("SplashIcon")
                    .resizable()
                    .scaledToFit()
                    .decorativeFrame(size: 160)
                    .clipShape(AppIconMask())
                    .shadow(
                        color: AccessibilityColors.brandPrimary.opacity(0.25),
                        radius: 12,
                        x: 0, y: 4
                    )
                    // 光は background に置き、レイアウトの高さに数えない
                    // (ZStack だと AX 最大で 240pt × 1.3 = 312pt を取り、サブタイトルが 1 行に潰れた)
                    .background {
                        Circle()
                            .fill(
                                EllipticalGradient(
                                    colors: [
                                        AccessibilityColors.brandAccent.opacity(0.5),
                                        Color.clear
                                    ],
                                    center: .center,
                                    // 半径は枠に対する比率で指定し、decorativeFrame で育っても光の幅を保つ。
                                    // 終端は枠の半径 (0.5) 以下にする。超えると色が消えきる前に円のふちで切れ、
                                    // dark で円盤の輪郭が見える
                                    startRadiusFraction: 0.2,
                                    endRadiusFraction: 0.5
                                )
                            )
                            .decorativeFrame(size: 240)
                            .opacity(glowIntensity)
                    }
                    .scaleEffect(iconScale)
                    .accessibilityHidden(true)
                
                // アプリタイトル
                VStack(spacing: 16) {
                    // #151 提案3: ロゴ (ワードマーク) 扱いで上限 1.3 倍 (約 46.8pt、幅 約 313pt)。上限なしだと
                    // AX5 で約 63pt (幅 約 417pt) になり 414pt 幅以下の端末で 1 行に収まらない。
                    // lineLimit + minimumScaleFactor は 320pt 幅では余白 約 7pt のため保険
                    Text("OtetsudaiCoin")
                        .decorativeFont(size: 36, weight: .bold, design: .rounded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(AccessibilityColors.splashText)
                        .opacity(titleOpacity)
                    
                    Text("お手伝いでコインを貯めよう！")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(AccessibilityColors.splashText)
                        .offset(y: subtitleOffset)
                        .opacity(titleOpacity)
                }
                
                Spacer()
                
                // シンプルなローディングインジケータ
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(AccessibilityColors.splashText.opacity(0.7))
                                .frame(width: 8, height: 8)
                                .scaleEffect(iconScale > 0.8 ? 1.1 : 0.9)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever()
                                    .delay(Double(index) * 0.15),
                                    value: iconScale
                                )
                        }
                    }
                    
                    Text("読み込み中...")
                        .font(.footnote)
                        .foregroundColor(AccessibilityColors.splashText)
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
        // アイコンのスケールアップ
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7, blendDuration: 0)) {
            iconScale = 1.0
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

/// iOS のアイコンマスクに近い角丸 (幅の 22.37%)。decorativeFrame で大きさが変わっても比率を保つ
private struct AppIconMask: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: rect.width * 0.2237, style: .continuous).path(in: rect)
    }
}

#Preview {
    SplashScreenView {
        DebugLogger.debug("Splash completed")
    }
}
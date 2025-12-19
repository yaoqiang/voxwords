import SwiftUI
import SpriteKit

struct POCDemoView: View {
    @State private var resetToken = UUID()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                moodHeaderLikeReference
                chartsCard
                Spacer(minLength: 24)
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("POC Demo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var moodHeaderLikeReference: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.07, blue: 0.08),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 12) {
                // Top pill
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())

                    VStack(spacing: 2) {
                        Text("心情盒子")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.92))
                        Text("已收集 16 个情绪")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }

                    Spacer()

                    Button {
                        // Stronger haptic here helps verify device haptics are working in this screen.
                        HapticManager.shared.mediumImpact()
                        resetToken = UUID()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .padding(10)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Balls + bowl
                ZStack(alignment: .bottom) {
                    // Black filled bowl to match the reference (MUST be behind balls)
                    BowlFillShape(rimRatio: 0.42, depthRatio: 0.33)
                        .fill(Color.black)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .allowsHitTesting(false)

                    MoodGravitySpriteContainer(resetToken: resetToken)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 280)
        .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 14)
    }

    private var chartsCard: some View {
        Group {
            if #available(iOS 16.0, *) {
                POCChartsSection()
            } else {
                Text("Swift Charts 需要 iOS 16+。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct MoodGravitySpriteContainer: View {
    let resetToken: UUID

    var body: some View {
        GeometryReader { proxy in
            let scene = MoodGravityScene(
                size: proxy.size,
                config: .init(
                    ballCount: 26,
                    ballRadius: 16,
                    gravity: .init(dx: 0, dy: -18),
                    usesDeviceGravity: true,
                    gravityStrength: 18,
                    gravitySmoothing: 0.18,
                    rimY: 84,
                    bowlDepth: 70,
                    simplifiedDropHaptics: false,
                    collisionImpulseThreshold: 0.9,
                    hapticMaxHz: 12
                )
            )
            SpriteView(scene: scene, options: [.allowsTransparency])
                .id(resetToken) // force re-create scene on refresh
                .ignoresSafeArea()
                .background(Color.clear)
                .allowsHitTesting(false) // avoid focus/interaction spam logs
                .focusable(false)
        }
    }
}

private struct BowlFillShape: Shape {
    var rimRatio: CGFloat // 0...1
    var depthRatio: CGFloat // 0...1

    func path(in rect: CGRect) -> Path {
        let rimY = rect.height * rimRatio
        // SwiftUI coordinate system: y grows downward, so "dip" should be larger y.
        let dipY = min(rect.maxY - 6, rimY + rect.height * depthRatio)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rimY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rimY),
            control: CGPoint(x: rect.midX, y: dipY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    NavigationStack {
        POCDemoView()
    }
}

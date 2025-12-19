import SwiftUI

/// Displays a vocabulary card with image, word, translation, and audio playback
/// Supports progressive loading states with smooth animations
struct CardView: View {
    // MARK: - Properties
    let card: VocabularyCard
    let onPlayAudio: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            imageSection
                .frame(height: 220)
                .clipped()
                .overlay(alignment: .bottom) {
                    if card.status != .loading {
                        stickerLabel
                            .offset(y: 16)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 20)
            
            contentSection
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 16)
                .background(Color.white)
        }
        .background(VoxTheme.Colors.cardSurface)
        .cornerRadius(VoxTheme.Dimensions.cardCornerRadius)
        .shadow(color: VoxTheme.Shadows.card, radius: VoxTheme.Shadows.cardRadius, y: VoxTheme.Shadows.cardY)
    }
    
    // MARK: - Image Section
    
    @ViewBuilder
    private var imageSection: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [
                    VoxTheme.Colors.warmCream.opacity(0.3),
                    VoxTheme.Colors.softPink.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if let url = card.imageURL, card.status == .complete {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        loadingPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .animation(.easeOut(duration: 0.4), value: card.imageURL)
                    case .failure:
                        imagePlaceholder
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else if card.status == .imageLoading {
                loadingPlaceholder
            } else {
                imagePlaceholder
            }
        }
    }
    
    private var stickerLabel: some View {
        VStack(spacing: 4) {
            Text(card.word)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(VoxTheme.Colors.deepBrown)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: VoxTheme.Shadows.card.opacity(0.6), radius: 6, y: 3)
            
            Text(card.translation)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(VoxTheme.Colors.warmGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: VoxTheme.Shadows.card.opacity(0.4), radius: 4, y: 2)
        }
        .padding(.vertical, 6)
    }
    
    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(VoxTheme.Colors.softPink)
            Text(card.status == .imageLoading ? "生成图片中..." : "加载中...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VoxTheme.Colors.warmGray.opacity(0.6))
        }
    }
    
    private var imagePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundColor(VoxTheme.Colors.warmGray.opacity(0.3))
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(spacing: 0) {
            if card.status == .loading {
                loadingSkeleton
            } else {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let category = card.category {
                            categoryTag(category)
                        }
                        
                        Text(card.targetLanguage.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(VoxTheme.Colors.warmGray.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    playButton
                }
            }
        }
    }
    
    private var playButton: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            onPlayAudio(card.word)
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                VoxTheme.Colors.warmPeach.opacity(0.15),
                                VoxTheme.Colors.softPink.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(VoxTheme.Colors.warmPeach)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func categoryTag(_ category: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: categoryIcon(for: category))
                .font(.system(size: 11, weight: .semibold))
            Text(category)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(VoxTheme.Colors.softPink)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(VoxTheme.Colors.softPink.opacity(0.1))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "动物": return "pawprint.fill"
        case "水果", "食物": return "leaf.fill"
        case "交通": return "car.fill"
        case "颜色": return "paintpalette.fill"
        case "身体": return "heart.fill"
        case "家庭": return "house.fill"
        default: return "tag.fill"
        }
    }
    
    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(VoxTheme.Colors.loading)
                .frame(width: 140, height: 28)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(VoxTheme.Colors.loading)
                .frame(width: 90, height: 16)
                .shimmering()
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Color.white
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .clear, location: 0.3),
                                            .init(color: .white.opacity(0.5), location: 0.5),
                                            .init(color: .clear, location: 0.7)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .rotationEffect(.degrees(30))
                                .offset(x: phase * geo.size.width * 2.5 - geo.size.width * 1.25)
                        )
                }
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CardView(card: VocabularyCard(
            id: UUID(),
            word: "Lion",
            translation: "狮子",
            nativeLanguage: "zh-CN",
            targetLanguage: "en-US",
            imageURL: nil,
            audioURL: nil,
            soundEffectURL: nil,
            sceneNote: nil,
            category: "动物",
            status: .textOnly,
            createdAt: Date()
        )) { _ in print("Play") }
        .padding(.horizontal, 24)
        
        CardView(card: VocabularyCard(
            id: UUID(),
            word: "Loading",
            translation: "加载中",
            nativeLanguage: "zh-CN",
            targetLanguage: "en-US",
            imageURL: nil,
            audioURL: nil,
            soundEffectURL: nil,
            sceneNote: nil,
            category: nil,
            status: .loading,
            createdAt: Date()
        )) { _ in }
        .padding(.horizontal, 24)
    }
    .padding(.vertical)
    .background(VoxTheme.Colors.warmCream)
}

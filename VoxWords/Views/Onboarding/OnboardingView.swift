import SwiftUI
import Translation

/// Onboarding flow for first-time users
/// Guides users through language selection with CapWords-style aesthetics
struct OnboardingView: View {
    // MARK: - Bindings
    @Binding var isCompleted: Bool
    
    // MARK: - App Storage
    @AppStorage("nativeLanguage") private var nativeLanguage: String = "zh-CN"
    @AppStorage("targetLanguage") private var targetLanguage: String = "en-US"
    
    // MARK: - State
    @State private var currentStep = 0
    @State private var selectedNativeLanguage: String?
    @State private var selectedTargetLanguage: String?
    @State private var showContent = false
    
    // Translation prewarm (iOS 18+)
    @StateObject private var prewarmPipeline = TranslationPipeline()
    @State private var isPreparingTranslation: Bool = false
    @State private var prepareError: String?
    
    var body: some View {
        ZStack {
            VoxTheme.Colors.canvas
                .ignoresSafeArea()
            
            OnboardingDotGridBackground()
                .ignoresSafeArea()
                .opacity(0.35)
            
            VStack(spacing: 0) {
                progressView
                    .padding(.top, 20)
                    .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                    .opacity(showContent ? 1 : 0)
                
                TabView(selection: $currentStep) {
                    welcomeStep
                        .tag(0)
                    
                    languageStep(
                        title: "你说什么语言？",
                        subtitle: "这是你和孩子的日常语言",
                        selection: $selectedNativeLanguage,
                        options: [
                            ("zh-CN", "中文", "🇨🇳"),
                            ("en-US", "English", "🇺🇸"),
                            ("ja-JP", "日本語", "🇯🇵"),
                            ("ko-KR", "한국어", "🇰🇷")
                        ]
                    )
                    .tag(1)
                    
                    languageStep(
                        title: "想学什么语言？",
                        subtitle: "我们会用这个语言生成卡片",
                        selection: $selectedTargetLanguage,
                        options: [
                            ("zh-CN", "中文", "🇨🇳"),
                            ("en-US", "English", "🇺🇸"),
                            ("ja-JP", "日本語", "🇯🇵"),
                            ("ko-KR", "한국어", "🇰🇷")
                        ]
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                .padding(.vertical, VoxTheme.Dimensions.padding)
                
                Spacer(minLength: VoxTheme.Dimensions.padding)
                
                footerCTA
                    .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                    .padding(.bottom, VoxTheme.Dimensions.largePadding)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
            }
        }
        .overlay(alignment: .topLeading) {
            TranslationHost(pipeline: prewarmPipeline)
        }
        .onAppear {
            initializeSelection()
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Components
    
    private var progressView: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i <= currentStep ? VoxTheme.Colors.softPink : VoxTheme.Colors.dotGrid.opacity(0.5))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .animation(.spring(), value: currentStep)
            }
        }
    }
    
    // MARK: - Steps
    
    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer(minLength: VoxTheme.Dimensions.padding)
            
            OnboardingHeroCard()
                .scaleEffect(showContent ? 1 : 0.92)
                .opacity(showContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: showContent)
            
            VStack(spacing: 14) {
                Text("VoxWords")
                    .font(VoxTheme.Typography.heroTitle)
                    .foregroundColor(VoxTheme.Colors.deepBrown)
                    .multilineTextAlignment(.center)
                
                Text("按住说一个中文词，比如「苹果」\n马上得到英文卡片，并一键听发音")
                    .font(VoxTheme.Typography.heroSubtitle)
                    .foregroundColor(VoxTheme.Colors.warmGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 12)
            .animation(.easeOut.delay(0.35), value: showContent)
            
            Spacer(minLength: VoxTheme.Dimensions.padding)
        }
        .padding(.horizontal, VoxTheme.Dimensions.largePadding)
    }
    
    private func languageStep(
        title: String,
        subtitle: String,
        selection: Binding<String?>,
        options: [(String, String, String)]
    ) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Text(title)
                    .font(VoxTheme.Typography.title)
                    .foregroundColor(VoxTheme.Colors.deepBrown)
                
                Text(subtitle)
                    .font(VoxTheme.Typography.body)
                    .foregroundColor(VoxTheme.Colors.warmGray)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 32)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(options, id: \.0) { option in
                    LanguageOption(
                        code: option.0,
                        name: option.1,
                        icon: option.2,
                        selection: selection
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func nextStep() {
        HapticManager.shared.lightImpact()
        withAnimation {
            if currentStep < 2 {
                currentStep += 1
            } else {
                let n = selectedNativeLanguage ?? nativeLanguage
                var t = selectedTargetLanguage ?? targetLanguage
                // Prevent native/target being the same.
                if t == n {
                    t = (n == "en-US") ? "zh-CN" : "en-US"
                }
                nativeLanguage = n
                targetLanguage = t
                isCompleted = true
            }
        }
    }
}

// MARK: - CapWords-style Components

private struct OnboardingDotGridBackground: View {
    private let spacing: CGFloat = 22
    private let dotSize: CGFloat = 2
    
    var body: some View {
        GeometryReader { proxy in
            let cols = Int(proxy.size.width / spacing)
            let rows = Int(proxy.size.height / spacing)
            Canvas { context, _ in
                for row in 0...rows {
                    for col in 0...cols {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                        context.fill(Path(ellipseIn: rect), with: .color(VoxTheme.Colors.dotGrid))
                    }
                }
            }
        }
    }
}

private struct OnboardingHeroCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: VoxTheme.Dimensions.cardCornerRadius)
                    .fill(VoxTheme.Colors.cardSurface)
                    .shadow(color: VoxTheme.Shadows.hero, radius: VoxTheme.Shadows.heroRadius, y: VoxTheme.Shadows.heroY)
                
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: VoxTheme.Dimensions.cardCornerRadius * 0.8)
                            .fill(VoxTheme.Colors.cardSurface)
                            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 8)
                            .rotationEffect(.degrees(-8))
                            .offset(y: 6)
                        
                        // No network image during onboarding (keeps first-run smooth)
                        RoundedRectangle(cornerRadius: VoxTheme.Dimensions.cardCornerRadius * 0.8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VoxTheme.Colors.warmCream.opacity(0.9),
                                        VoxTheme.Colors.softPink.opacity(0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: VoxTheme.Dimensions.heroImageSize, height: VoxTheme.Dimensions.heroImageSize)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundColor(VoxTheme.Colors.warmGray.opacity(0.35))
                            )
                            .rotationEffect(.degrees(-8))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 6)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Un Cornet De Glace")
                            .font(VoxTheme.Typography.wordDisplay)
                            .foregroundColor(VoxTheme.Colors.deepBrown)
                        
                        Text("Ice cream cone · 法语示例词")
                            .font(VoxTheme.Typography.body)
                            .foregroundColor(VoxTheme.Colors.warmGray)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
                }
                .padding(VoxTheme.Dimensions.largePadding)
            }
        }
    }
}

private extension OnboardingView {
    var footerCTA: some View {
        VStack(spacing: 14) {
            Button(action: nextStep) {
                Text(currentStep == 2 ? "开始体验" : "下一步")
                    .font(VoxTheme.Typography.headline)
                    .foregroundColor(VoxTheme.Colors.accentYellow)
                    .frame(maxWidth: .infinity)
                    .frame(height: VoxTheme.Dimensions.ctaHeight)
                    .background(VoxTheme.Colors.ctaDark)
                    .cornerRadius(VoxTheme.Dimensions.ctaHeight / 2)
                    .shadow(color: VoxTheme.Shadows.button, radius: VoxTheme.Shadows.buttonRadius, y: VoxTheme.Shadows.buttonY)
            }
            .buttonStyle(ScaleButtonStyle())
            
            if currentStep == 2 {
                Button(action: prepareTranslation) {
                    HStack(spacing: 8) {
                        if isPreparingTranslation {
                            ProgressView().tint(VoxTheme.Colors.warmGray)
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isPreparingTranslation ? "正在准备离线翻译…" : "准备离线翻译（可选）")
                            .font(VoxTheme.Typography.body)
                    }
                    .foregroundColor(VoxTheme.Colors.warmGray)
                }
                .disabled(isPreparingTranslation)
                
                if let prepareError {
                    Text(prepareError)
                        .font(VoxTheme.Typography.caption)
                        .foregroundColor(VoxTheme.Colors.warmGray.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
            }
            
            HStack(spacing: 6) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VoxTheme.Colors.warmGray.opacity(0.8))
                Text("Audio-first · CapWords-inspired")
                    .font(VoxTheme.Typography.caption)
                    .foregroundColor(VoxTheme.Colors.warmGray.opacity(0.8))
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Helpers
extension OnboardingView {
    private func initializeSelection() {
        // Initialize selections from stored AppStorage values or sensible defaults
        selectedNativeLanguage = nativeLanguage
        selectedTargetLanguage = targetLanguage == nativeLanguage ? "en-US" : targetLanguage
    }
    
    @MainActor
    private func prepareTranslation() {
        guard #available(iOS 18.0, *) else { return }
        guard let src = selectedNativeLanguage ?? nativeLanguage as String?,
              let dst = selectedTargetLanguage ?? targetLanguage as String? else { return }
        isPreparingTranslation = true
        prepareError = nil
        
        prewarmPipeline.setLanguagePair(
            source: Locale.Language(identifier: src),
            target: Locale.Language(identifier: dst)
        )
        
        Task { @MainActor in
            let result = await prewarmPipeline.translate(id: UUID(), text: "苹果")
            self.isPreparingTranslation = false
            switch result {
            case .success:
                self.prepareError = nil
            case .failure:
                self.prepareError = "准备失败：可能需要先下载离线语言包"
            }
        }
    }
}

struct LanguageOption: View {
    let code: String
    let name: String
    let icon: String
    @Binding var selection: String?
    
    var isSelected: Bool { selection == code }
    
    var body: some View {
        Button(action: {
            // Update state FIRST for immediate visual feedback
            selection = code
            // Haptic can run async - it's already pre-warmed
            HapticManager.shared.selectionChanged()
        }) {
            VStack(spacing: 12) {
                Text(icon).font(.system(size: 40))
                Text(name)
                    .font(VoxTheme.Typography.headline)
                    .foregroundColor(isSelected ? VoxTheme.Colors.deepBrown : VoxTheme.Colors.warmGray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color.white)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? VoxTheme.Colors.softPink : Color.clear, lineWidth: 4)
            )
            .shadow(
                color: isSelected ? VoxTheme.Colors.softPink.opacity(0.3) : VoxTheme.Shadows.card,
                radius: isSelected ? 12 : 8,
                y: isSelected ? 6 : 4
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            // Use implicit animation instead of explicit withAnimation for smoother response
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain) // Prevents default button press animation that can cause lag
    }
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}

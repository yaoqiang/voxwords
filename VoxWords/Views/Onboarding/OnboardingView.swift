import SwiftUI
import Foundation

/// Onboarding flow for first-time users
/// Guides users through language selection with VoxWords aesthetics
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
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                progressView
                    .padding(.top, 20)
                    .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                    .opacity(showContent ? 1 : 0)
                
                TabView(selection: $currentStep) {
                    welcomeStep
                        .tag(0)
                    
                    languageStep(
                        title: String(localized: "onboarding.native.title"),
                        subtitle: String(localized: "onboarding.native.subtitle"),
                        selection: $selectedNativeLanguage,
                        options: LanguageManager.supportedLanguages
                    )
                    .tag(1)
                    
                    languageStep(
                        title: String(localized: "onboarding.target.title"),
                        subtitle: String(localized: "onboarding.target.subtitle"),
                        selection: $selectedTargetLanguage,
                        options: LanguageManager.supportedLanguages
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
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                Text(String(localized: "onboarding.welcome.subtitle"))
                    .font(VoxTheme.Typography.heroSubtitle)
                    .foregroundStyle(.secondary)
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(VoxTheme.Typography.title)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(VoxTheme.Typography.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                
                // Adaptive grid so more languages fit on-screen.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(options, id: \.0) { option in
                        LanguageOption(
                            code: option.0,
                            name: option.1,
                            icon: option.2,
                            selection: selection
                        )
                    }
                }
                .padding(.horizontal, 4)
                
                // Leave space above the CTA area.
                Spacer(minLength: 90)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
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

    // MARK: - Components

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
                RoundedRectangle(cornerRadius: VoxTheme.Dimensions.cardCornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassCard(cornerRadius: VoxTheme.Dimensions.cardCornerRadius)
                
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: VoxTheme.Dimensions.cardCornerRadius * 0.8, style: .continuous)
                            .fill(.clear)
                            .glassCard(cornerRadius: VoxTheme.Dimensions.cardCornerRadius * 0.8)
                            .rotationEffect(.degrees(-8))
                            .offset(y: 6)
                        
                        // No network image during onboarding (keeps first-run smooth)
                        RoundedRectangle(cornerRadius: VoxTheme.Dimensions.cardCornerRadius * 0.8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.20),
                                        VoxTheme.Colors.softPink.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: VoxTheme.Dimensions.heroImageSize, height: VoxTheme.Dimensions.heroImageSize)
                            .overlay(
                                VStack(spacing: 10) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundStyle(.secondary.opacity(0.7))
                                    
                                    HStack(spacing: 10) {
                                        MiniWordChip(text: "CAT", systemIcon: "speaker.wave.2.fill")
                                        MiniWordChip(text: "猫", systemIcon: nil)
                                    }
                                }
                            )
                            .rotationEffect(.degrees(-8))
                            .shadow(color: Color.black.opacity(0.10), radius: 10, y: 6)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Cat")
                            .font(VoxTheme.Typography.wordDisplay)
                            .foregroundStyle(.primary)
                        
                        Text(String(localized: "onboarding.hero.hint"))
                            .font(VoxTheme.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
                }
                .padding(VoxTheme.Dimensions.largePadding)
            }
        }
    }
}

private struct MiniWordChip: View {
    let text: String
    let systemIcon: String?
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).stroke(VoxTheme.Glass.stroke, lineWidth: VoxTheme.Glass.strokeWidth))
        )
    }
}

private extension OnboardingView {
    var footerCTA: some View {
        VStack(spacing: 14) {
            Button(action: nextStep) {
                Text(currentStep == 2
                     ? String(localized: "onboarding.cta.start")
                     : String(localized: "onboarding.cta.next"))
                    .font(VoxTheme.Typography.headline)
                    .foregroundColor(VoxTheme.Colors.accentYellow)
                    .frame(maxWidth: .infinity)
                    .frame(height: VoxTheme.Dimensions.ctaHeight)
                    .background(VoxTheme.Colors.ctaDark)
                    .cornerRadius(VoxTheme.Dimensions.ctaHeight / 2)
                    .shadow(color: VoxTheme.Shadows.button, radius: VoxTheme.Shadows.buttonRadius, y: VoxTheme.Shadows.buttonY)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Text(String(localized: "onboarding.tagline"))
                .font(VoxTheme.Typography.caption)
                .foregroundStyle(.secondary.opacity(0.85))
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
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .glassCard(cornerRadius: 24)
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

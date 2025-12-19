import SwiftUI

/// CapWords-inspired Settings sheet.
/// - Keeps it minimal for now (local-only app).
/// - Language changes are handled by re-running onboarding.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("nativeLanguage") private var nativeLanguage: String = "zh-CN"
    @AppStorage("targetLanguage") private var targetLanguage: String = "en-US"

    @State private var showLanguageSheet: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        HapticManager.shared.selectionChanged()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.70))
                            .padding(10)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, 6)

                Text("Settings")
                    .font(.system(size: 36, weight: .regular, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .padding(.top, 4)

                SettingsSection(title: "Learning") {
                    SettingsRow(
                        icon: "globe",
                        title: "Change learning language"
                    ) {
                        HapticManager.shared.selectionChanged()
                        showLanguageSheet = true
                    }
                }

                SettingsSection(title: "Support") {
                    SettingsRow(icon: "envelope", title: "Contact & Support") {}
                    SettingsRow(icon: "a.circle", title: "FAQs") {}
                    SettingsRow(icon: "doc.text", title: "Terms of Use") {}
                    SettingsRow(icon: "lock", title: "Privacy Policy") {}
                }

                SettingsSection(title: "About") {
                    SettingsRow(icon: "moon.stars", title: "Our Story") {}
                    SettingsRow(icon: "link", title: "KOL partnership") {}
                    SettingsRow(icon: "sparkles", title: "Suggest a Feature") {}
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.bottom, 26)
        }
        .background(DotGridBackground().ignoresSafeArea())
        .sheet(isPresented: $showLanguageSheet) {
            LanguageSettingsSheet(
                nativeLanguage: $nativeLanguage,
                targetLanguage: $targetLanguage
            )
        }
    }
}

private func languageName(_ code: String) -> String {
    switch code {
    case "zh-CN": return "中文"
    case "en-US": return "English"
    case "ja-JP": return "日本語"
    case "ko-KR": return "한국어"
    default: return code
    }
}

private struct LanguageSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var nativeLanguage: String
    @Binding var targetLanguage: String

    @State private var selectedNative: String?
    @State private var selectedTarget: String?

    private let nativeOptions: [(String, String, String)] = [
        ("zh-CN", "中文", "🇨🇳"),
        ("en-US", "English", "🇺🇸"),
        ("ja-JP", "日本語", "🇯🇵"),
        ("ko-KR", "한국어", "🇰🇷")
    ]

    private let targetOptions: [(String, String, String)] = [
        ("zh-CN", "中文", "🇨🇳"),
        ("en-US", "English", "🇺🇸"),
        ("ja-JP", "日本語", "🇯🇵"),
        ("ko-KR", "한국어", "🇰🇷")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    HapticManager.shared.selectionChanged()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.70))
                        .padding(10)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 8)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    HapticManager.shared.lightImpact()
                    nativeLanguage = selectedNative ?? nativeLanguage
                    targetLanguage = selectedTarget ?? targetLanguage
                    // Prevent "same language" footgun.
                    if targetLanguage == nativeLanguage {
                        targetLanguage = (nativeLanguage == "en-US") ? "zh-CN" : "en-US"
                    }
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.88))
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.top, 10)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Languages")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Native")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.35))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(nativeOptions, id: \.0) { opt in
                                LanguageOption(code: opt.0, name: opt.1, icon: opt.2, selection: $selectedNative)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.35))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(targetOptions, id: \.0) { opt in
                                LanguageOption(code: opt.0, name: opt.1, icon: opt.2, selection: $selectedTarget)
                            }
                        }
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                .padding(.bottom, 24)
            }
        }
        .background(DotGridBackground().ignoresSafeArea())
        .onAppear {
            selectedNative = nativeLanguage
            selectedTarget = targetLanguage
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.35))

            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
        }
        .padding(.top, 8)
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.80))

                Spacer()

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.35))
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .overlay(
            Divider()
                .opacity(0.12)
                .padding(.leading, 56),
            alignment: .bottom
        )
    }
}


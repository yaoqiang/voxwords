import SwiftUI
import UIKit
import StoreKit

/// VoxWords Settings sheet.
/// - Keeps it minimal for now (local-only app).
/// - Language changes are handled by re-running onboarding.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchase: PurchaseManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("nativeLanguage") private var nativeLanguage: String = "zh-CN"
    @AppStorage("targetLanguage") private var targetLanguage: String = "en-US"
    // 0 = slow, 1 = normal, 2 = fast
    @AppStorage("ttsSpeechRateLevel") private var ttsSpeechRateLevel: Int = 1

    @State private var showLanguageSheet: Bool = false
    @State private var showSupportLinksAlert: Bool = false
    @State private var showAbout: Bool = false
    @State private var showFAQ: Bool = false
    @State private var showSpeechRateSheet: Bool = false
    @State private var showAppearanceSheet: Bool = false
    @State private var showPaywall: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0 // 0 = system, 1 = light, 2 = dark

    private var speechRateLabel: String {
        switch ttsSpeechRateLevel {
        case 0:
            return String(localized: "settings.speech.rate.slow")
        case 2:
            return String(localized: "settings.speech.rate.fast")
        default:
            return String(localized: "settings.speech.rate.normal")
        }
    }

    private var appearanceModeLabel: String {
        switch appearanceMode {
        case 1:
            return String(localized: "settings.appearance.light")
        case 2:
            return String(localized: "settings.appearance.dark")
        default:
            return String(localized: "settings.appearance.system")
        }
    }

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
                            .foregroundStyle(.primary.opacity(0.75))
                            .padding(10)
                            .glassIconCircle(size: 44)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, 6)

                Text(String(localized: "settings.title"))
                    .font(.system(size: 36, weight: .regular, design: .serif))
                    .foregroundStyle(.primary.opacity(0.92))
                    .padding(.top, 4)

                SettingsSection(title: String(localized: "settings.section.learning")) {
                    SettingsRow(
                        icon: "crown.fill",
                        title: String(localized: "settings.upgrade.title"),
                        subtitle: purchase.isPremium ? String(localized: "settings.upgrade.active") : String(localized: "settings.upgrade.subtitle")
                    ) {
                        HapticManager.shared.selectionChanged()
                        showPaywall = true
                    }

                    SettingsRow(
                        icon: "globe",
                        title: String(localized: "settings.learning.change_language")
                    ) {
                        HapticManager.shared.selectionChanged()
                        showLanguageSheet = true
                    }

                    SettingsRow(
                        icon: "gearshape",
                        title: String(localized: "settings.learning.system_language"),
                        subtitle: String(localized: "settings.learning.system_language.subtitle")
                    ) {
                        HapticManager.shared.selectionChanged()
                        openSystemSettings()
                    }

                    SettingsRow(
                        icon: "waveform",
                        title: String(localized: "settings.speech.rate.title"),
                        subtitle: speechRateLabel
                    ) {
                        HapticManager.shared.selectionChanged()
                        showSpeechRateSheet = true
                    }
                }

                SettingsSection(title: String(localized: "settings.appearance.title")) {
                    SettingsRow(
                        icon: "paintbrush.fill",
                        title: String(localized: "settings.appearance.title"),
                        subtitle: appearanceModeLabel
                    ) {
                        HapticManager.shared.selectionChanged()
                        showAppearanceSheet = true
                    }
                }

                SettingsSection(title: String(localized: "settings.section.support")) {
                    SettingsRow(icon: "envelope", title: String(localized: "support.contact")) { openSupportLink(.contact) }
                    SettingsRow(icon: "a.circle", title: String(localized: "support.faq")) {
                        HapticManager.shared.selectionChanged()
                        showFAQ = true
                    }
                    SettingsRow(icon: "doc.text", title: String(localized: "support.terms")) { openSupportLink(.terms) }
                    SettingsRow(icon: "lock", title: String(localized: "support.privacy")) { openSupportLink(.privacy) }
                }

                SettingsSection(title: String(localized: "settings.section.about")) {
                    SettingsRow(icon: "info.circle", title: String(localized: "about.voxwords")) {
                        HapticManager.shared.selectionChanged()
                        showAbout = true
                    }
                    SettingsRow(icon: "sparkles", title: String(localized: "about.suggest_feature")) {
                        HapticManager.shared.selectionChanged()
                        openAppStoreForFeedback()
                    }
                }

                VStack(spacing: 10) {
                    Text(String(localized: "settings.footer.made_by"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(String(localized: "settings.footer.made_with"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.bottom, 26)
        }
        .background(LiquidGlassBackground().ignoresSafeArea())
        .sheet(isPresented: $showLanguageSheet) {
            LanguageSettingsSheet(
                nativeLanguage: $nativeLanguage,
                targetLanguage: $targetLanguage
            )
        }
        .sheet(isPresented: $showAbout) {
            AboutVoxWordsView()
        }
        .sheet(isPresented: $showFAQ) {
            FAQView()
        }
        .sheet(isPresented: $showSpeechRateSheet) {
            SpeechRateSheet(level: $ttsSpeechRateLevel)
        }
        .sheet(isPresented: $showAppearanceSheet) {
            AppearanceModeSheet(mode: $appearanceMode)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert(String(localized: "support.links_missing.title"), isPresented: $showSupportLinksAlert) {
            Button(String(localized: "support.links_missing.ok"), role: .cancel) {}
        } message: {
            Text(String(localized: "support.links_missing.message"))
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private enum SupportDestination {
        case contact
        case faq
        case terms
        case privacy
        case about
    }

    /// Placeholder links. You will paste Notion links later and we'll replace these.
    private func url(for dest: SupportDestination) -> URL? {
        switch dest {
        case .contact: return URL(string: "https://thin-tuba-90a.notion.site/2cfa939e504780a3a456c4754b28e442")//thin-tuba-90a.notion.site/2cfa939e504780a3a456c4754b28e442?source=copy_link)
        case .faq: return nil // now in-app
        case .terms: return URL(string: "https://thin-tuba-90a.notion.site/2cfa939e504780909350eff2f5c76e77?pvs=74")
        case .privacy: return URL(string: "https://thin-tuba-90a.notion.site/2cfa939e504780129e73df8ff650892e")
        case .about: return nil
        }
    }

    private func openSupportLink(_ dest: SupportDestination) {
        guard let url = url(for: dest) else {
            showSupportLinksAlert = true
            return
        }
        UIApplication.shared.open(url)
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    private func openAppStoreForFeedback() {
        // VoxWords App Store ID: 6756831947
        // 直接打开 App Store 并自动弹出评论页面
        let appStoreID = "6756831947"
        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

private struct FAQView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LiquidGlassBackground().ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Button {
                        HapticManager.shared.selectionChanged()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.75))
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .glassIconCircle(size: 40)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(String(localized: "faq.title"))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(.primary.opacity(0.92))

                    FAQItem(
                        q: String(localized: "faq.q1"),
                        a: String(localized: "faq.a1")
                    )
                    FAQItem(
                        q: String(localized: "faq.q2"),
                        a: String(localized: "faq.a2")
                    )
                    FAQItem(
                        q: String(localized: "faq.q3"),
                        a: String(localized: "faq.a3")
                    )
                    FAQItem(
                        q: String(localized: "faq.q4"),
                        a: String(localized: "faq.a4")
                    )
                    FAQItem(
                        q: String(localized: "faq.q5"),
                        a: String(localized: "faq.a5")
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassCard(cornerRadius: 26)

                Spacer()
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
    }
}

private struct FAQItem: View {
    let q: String
    let a: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(q)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.80))
            Text(a)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AboutVoxWordsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LiquidGlassBackground().ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Button {
                        HapticManager.shared.selectionChanged()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.70))
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .glassIconCircle(size: 40)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "about.page.title"))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.88))

                    Text(String(localized: "about.page.body"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassCard(cornerRadius: 26)

                Spacer()

                Button {
                    HapticManager.shared.lightImpact()
                    dismiss()
                } label: {
                    Text(String(localized: "about.page.cta"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .glassCard(cornerRadius: 18)
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
    }
}

private func languageName(_ code: String) -> String {
    return LanguageManager.displayName(for: code)
}

private struct LanguageSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var nativeLanguage: String
    @Binding var targetLanguage: String

    @State private var selectedNative: String?
    @State private var selectedTarget: String?

    private let nativeOptions: [(String, String, String)] = LanguageManager.supportedLanguages
    private let targetOptions: [(String, String, String)] = LanguageManager.supportedLanguages

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
                    Text(String(localized: "settings.sheet.save"))
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
                    Text(String(localized: "settings.sheet.languages"))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "settings.sheet.native"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.35))

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(nativeOptions, id: \.0) { opt in
                                SettingsLanguageOption(code: opt.0, name: opt.1, icon: opt.2, selection: $selectedNative)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "settings.sheet.target"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.35))

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(targetOptions, id: \.0) { opt in
                                SettingsLanguageOption(code: opt.0, name: opt.1, icon: opt.2, selection: $selectedTarget)
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

/// Lighter weight option cell for the Settings language sheet (reduces scroll jank).
private struct SettingsLanguageOption: View {
    let code: String
    let name: String
    let icon: String
    @Binding var selection: String?
    
    private var isSelected: Bool { selection == code }
    
    var body: some View {
        Button {
            selection = code
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 10) {
                Text(icon)
                    .font(.system(size: 22))
                
                Text(name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .glassCard(cornerRadius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VoxTheme.Colors.softPink.opacity(isSelected ? 0.75 : 0.0), lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                content
            }
            .glassCard(cornerRadius: 22)
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
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .overlay(
            Divider()
                .opacity(0.10)
                .padding(.leading, 56),
            alignment: .bottom
        )
    }
}

private struct SpeechRateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var level: Int // 0 slow, 1 normal, 2 fast

    var body: some View {
        ZStack {
            LiquidGlassBackground().ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Button {
                        HapticManager.shared.selectionChanged()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.75))
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .glassIconCircle(size: 40)

                    Spacer()
                }
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "settings.speech.rate.title"))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(.primary.opacity(0.92))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    SpeedOption(
                        title: String(localized: "settings.speech.rate.slow"),
                        isSelected: level == 0
                    ) {
                        HapticManager.shared.lightImpact()
                        level = 0
                    }

                    SpeedOption(
                        title: String(localized: "settings.speech.rate.normal"),
                        isSelected: level == 1
                    ) {
                        HapticManager.shared.lightImpact()
                        level = 1
                    }

                    SpeedOption(
                        title: String(localized: "settings.speech.rate.fast"),
                        isSelected: level == 2
                    ) {
                        HapticManager.shared.lightImpact()
                        level = 2
                    }
                }

                Spacer()
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.bottom, 18)
        }
    }
}

private struct SpeedOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.22 : 0.0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AppearanceModeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var mode: Int // 0 = system, 1 = light, 2 = dark

    var body: some View {
        ZStack {
            LiquidGlassBackground().ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Button {
                        HapticManager.shared.selectionChanged()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.75))
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .glassIconCircle(size: 40)

                    Spacer()
                }
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "settings.appearance.title"))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(.primary.opacity(0.92))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    AppearanceOption(
                        title: String(localized: "settings.appearance.system"),
                        isSelected: mode == 0
                    ) {
                        HapticManager.shared.lightImpact()
                        mode = 0
                    }

                    AppearanceOption(
                        title: String(localized: "settings.appearance.light"),
                        isSelected: mode == 1
                    ) {
                        HapticManager.shared.lightImpact()
                        mode = 1
                    }

                    AppearanceOption(
                        title: String(localized: "settings.appearance.dark"),
                        isSelected: mode == 2
                    ) {
                        HapticManager.shared.lightImpact()
                        mode = 2
                    }
                }

                Spacer()
            }
            .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            .padding(.bottom, 18)
        }
    }
}

private struct AppearanceOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.22 : 0.0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


import SwiftUI
import SwiftData

/// Main app entry point for VoxWords
/// Manages onboarding state and language preferences
@main
struct VoxWordsApp: App {
    // MARK: - App Storage
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("nativeLanguage") private var nativeLanguage = "zh-CN"
    @AppStorage("targetLanguage") private var targetLanguage = "en-US"
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0 // 0 = system, 1 = light, 2 = dark

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var store = AppStore()
    @StateObject private var purchase = PurchaseManager()

    @State private var didSchedulePostLaunchWarmups: Bool = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView(speechManager: speechManager, store: store)
                } else {
                    OnboardingView(isCompleted: $hasCompletedOnboarding)
                }
            }
            .environmentObject(purchase)
            .preferredColorScheme(appearanceMode == 0 ? nil : (appearanceMode == 1 ? .light : .dark))
            .overlay {
                // Keep TranslationSession alive across navigation changes.
                if hasCompletedOnboarding {
                    TranslationHost(pipeline: store.translationPipeline)
                }
            }
            .onAppear {
                // Start observing entitlements early so "restore" reflects immediately.
                purchase.start()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                guard hasCompletedOnboarding else { return }
                scheduleWarmupsIfNeeded()
            }
            .onChange(of: hasCompletedOnboarding) { _, newValue in
                // If the user completes onboarding, schedule warmups once we become active.
                guard newValue == true else { return }
                if scenePhase == .active {
                    scheduleWarmupsIfNeeded()
                }
            }
        }
        .modelContainer(for: [WordEntry.self])
    }
}

// MARK: - Post-launch warmups (avoid blocking first render)
extension VoxWordsApp {
    private func scheduleWarmupsIfNeeded() {
        guard didSchedulePostLaunchWarmups == false else { return }
        didSchedulePostLaunchWarmups = true

        // NOTE:
        // Output warmup can still occasionally take several seconds depending on audio-server state / route.
        // We therefore only attempt it after a longer idle delay, and only if the user isn't recording.
        //
        // (Also: avoid doing anything that could trigger IPCAUClient logs during the initial cold-start window.)
        Task(priority: .utility) { [speechManager] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard Task.isCancelled == false else { return }
            let shouldWarm = await MainActor.run { speechManager.isRecording == false }
            guard shouldWarm else { return }
            speechManager.prewarmAudioOutput()
        }
    }
}

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

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var store = AppStore()

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
            .overlay {
                // Keep TranslationSession alive across navigation changes.
                if hasCompletedOnboarding {
                    TranslationHost(pipeline: store.translationPipeline)
                }
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

        // Delay warmups until after first render, so cold start remains smooth.
        Task(priority: .utility) { [speechManager] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            // Only warm the OUTPUT path; input priming can be noticeably expensive on cold start.
            speechManager.prewarmAudioOutput()
            // Do NOT prewarm TTS voice on launch; AVSpeechSynthesizer can trigger blocking IPC work.
            // Voice warmup will happen on-demand when the user taps speak, and when they change target language.
        }
    }
}

import UIKit
import CoreHaptics

/// A singleton manager for providing consistent haptic feedback throughout the app.
/// Designed for "silky" micro-interactions that feel responsive and alive.
@MainActor
final class HapticManager {
    // MARK: - Singleton
    static let shared = HapticManager()
    
    // MARK: - Properties
    private var hapticEngine: CHHapticEngine?

    // Reused generators (more reliable for frequent impacts)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Initialization
    private init() {
        prepareHaptics()
        prepareAllGenerators()
    }
    
    /// Pre-warm all haptic generators to eliminate first-tap latency
    private func prepareAllGenerators() {
        lightGenerator.prepare()
        softGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        rigidGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            // Auto-restart if engine stops
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason.rawValue)")
                self?.restartEngine()
            }
            
            hapticEngine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                self?.restartEngine()
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func restartEngine() {
        do {
            try hapticEngine?.start()
        } catch {
            print("Failed to restart haptic engine: \(error)")
        }
    }
    
    // MARK: - Standard Feedback
    
    /// Light tap - for button touch down
    func lightImpact() {
        lightGenerator.impactOccurred()
        lightGenerator.prepare() // Re-prepare for next use
    }
    
    /// Medium tap - for confirmations
    func mediumImpact() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }
    
    /// Heavy tap - for major actions
    func heavyImpact() {
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }
    
    /// Soft tap - subtle feedback
    func softImpact() {
        softGenerator.impactOccurred()
        softGenerator.prepare()
    }
    
    /// Rigid tap - crisp feedback
    func rigidImpact() {
        rigidGenerator.impactOccurred()
        rigidGenerator.prepare()
    }
    
    /// Success notification
    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    /// Warning notification
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    /// Error notification
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
    
    /// Selection changed - for picker/scroll
    func selectionChanged() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    /// A high-reliability impact used for physics collisions (0...1).
    /// Prefer this over CoreHaptics for very frequent triggers.
    func physicsImpact(intensity: CGFloat) {
        let i = max(0, min(1, intensity))
        softGenerator.prepare()
        // iOS supports intensity parameter; if it ever fails, fallback occurs naturally.
        softGenerator.impactOccurred(intensity: i)
    }

    // MARK: - Custom Patterns (CoreHaptics)
    
    /// "Pop" feeling - for recording button press
    func recordingStart() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            lightImpact()
            return
        }
        
        do {
            // Sharp initial hit + slight buzz
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            lightImpact()
        }
    }
    
    /// "Bloom" feeling - for recording button release with success
    func recordingSuccess() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            success()
            return
        }
        
        do {
            var events: [CHHapticEvent] = []
            
            // Initial pop
            let pop = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0
            )
            events.append(pop)
            
            // Soft decay wave
            let decay = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0.05,
                duration: 0.15
            )
            events.append(decay)
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            success()
        }
    }

    /// A configurable transient haptic (best for physics collisions).
    /// - Parameters:
    ///   - intensity: 0...1
    ///   - sharpness: 0...1
    func transient(intensity: Float, sharpness: Float) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            // Fallback mapping
            if intensity > 0.65 {
                mediumImpact()
            } else {
                softImpact()
            }
            return
        }

        do {
            let i = max(0, min(1, intensity))
            let s = max(0, min(1, sharpness))
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: i),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: s)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            softImpact()
        }
    }

    /// A soft "rain" burst for the mood balls drop.
    /// Designed to be noticeable but not noisy, and to avoid high-frequency spam.
    func moodBallsDropBurst() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            // Fallback: 6 gentle taps (~6Hz) to avoid rate-limit logs.
            Task { @MainActor in
                for i in 0..<6 {
                    self.softImpact()
                    try? await Task.sleep(nanoseconds: UInt64(160_000_000 + i * 10_000_000))
                }
            }
            return
        }

        do {
            // Continuous base (1.0s) + a few soft transients on top.
            let base = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
                ],
                relativeTime: 0,
                duration: 1.0
            )

            let accents: [CHHapticEvent] = stride(from: 0.15, through: 0.95, by: 0.16).map { t in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
                    ],
                    relativeTime: t
                )
            }

            let pattern = try CHHapticPattern(events: [base] + accents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            softImpact()
        }
    }
}

import Foundation
import Speech
@preconcurrency import AVFoundation
import NaturalLanguage
import OSLog

/// Manages speech recognition and text-to-speech functionality
/// 
/// **On-device speech notes:**
/// - SFSpeechRecognizer supports locale-specific models; set `locale` to user native language
/// - On-device recognition (iOS 13+) toggled via `requiresOnDeviceRecognition = true` but only works when the system has downloaded the dictation pack for that locale
/// - Language availability: Apple ships strong coverage for en, zh, es, fr, de, ja, ko, pt; niche locales may fall back to server
/// - Offline accuracy is slightly lower than server; keep partial results on for responsiveness
/// - Permissions: requires `NSSpeechRecognitionUsageDescription` + microphone usage string in Info.plist
/// - Next steps if we want stricter offline: prompt user to download "On‑device dictation" for their locale in Settings > General > Keyboard > Dictation
/// - Intent/subject extraction: not available natively; would require a local LLM (e.g., CoreML-backed small model) or cloud. For now we only stream transcript + dominant language
final class SpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    // MARK: - Published Properties
    @Published private(set) var transcript: String = ""
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var error: String?
    @Published private(set) var detectedLanguage: String?
    
    // MARK: - Configuration
    /// Toggle to force on-device ASR when the locale has a downloaded dictation pack
    var prefersOnDeviceRecognition: Bool = false
    /// Keep audio session active between recordings to avoid first-stop lag
    var keepsAudioSessionActive: Bool = true
    /// Keep audio engine running between sessions to reduce first-start latency
    var keepEngineRunningBetweenSessions: Bool = true
    /// Optional: record a single word/short phrase and auto-stop on silence.
    /// For MVP UX we default to user-controlled (release-to-stop).
    var oneWordModeEnabled: Bool = false
    /// Silence duration (nanoseconds) after speech to auto-stop.
    var oneWordSilenceDurationNs: UInt64 = 450_000_000
    /// Threshold to consider "speech started" (0...1 normalized level).
    var oneWordStartThreshold: Float = 0.08
    /// Threshold to consider "not silent" once speech has started (0...1 normalized level).
    var oneWordSilenceThreshold: Float = 0.04
    
    /// TTS speech rate (0.0 to 1.0, where 0.5 is default/normal speed).
    /// Reads from UserDefaults on each speak() call to respect Settings changes.
    private var speechRate: Float {
        let base = AVSpeechUtteranceDefaultSpeechRate

        // New: 3-level setting (0 slow, 1 normal, 2 fast).
        if let level = (UserDefaults.standard.object(forKey: "ttsSpeechRateLevel") as? NSNumber)?.intValue {
            switch level {
            case 0:
                return max(AVSpeechUtteranceMinimumSpeechRate, base * 0.72)
            case 2:
                return min(AVSpeechUtteranceMaximumSpeechRate, base * 1.28)
            default:
                return base
            }
        }

        // Back-compat: older slider stored normalized 0...1 under "ttsSpeechRate".
        let n = (UserDefaults.standard.object(forKey: "ttsSpeechRate") as? NSNumber)
        let t = min(max(n?.doubleValue ?? 0.5, 0.0), 1.0)
        let slow = max(AVSpeechUtteranceMinimumSpeechRate, base * 0.72)
        let fast = min(AVSpeechUtteranceMaximumSpeechRate, base * 1.28)
        return slow + (fast - slow) * Float(t)
    }
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.angyee.voxwords", category: "speech")
    private let audioQueue = DispatchQueue(label: "com.angyee.voxwords.audio", qos: .userInitiated)
    /// Dedicated queue for slow AudioUnit warmups so we never block `audioQueue` (user interactions).
    private let warmupQueue = DispatchQueue(label: "com.angyee.voxwords.audioWarmup", qos: .utility)
    
    private enum RecordingState {
        case idle
        case starting
        case recording
        case stopping
    }
    
    private var state: RecordingState = .idle
    private var hasPrewarmed: Bool = false
    private var currentAudioCategory: AVAudioSession.Category?
    private var currentAudioMode: AVAudioSession.Mode?
    private var didSetPreferredIO: Bool = false
    private var isAudioSessionActive: Bool = false
    private var didReceiveNonEmptyAudioBuffer: Bool = false
    private var lastRecordingStartNs: UInt64 = 0

    // Timing (nanoseconds) for diagnosing first-interaction stalls.
    private var lastRecordPressNs: UInt64?
    private var lastSpeakRequestNs: UInt64?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // TTS
    private let synthesizer = AVSpeechSynthesizer()
    private var ttsPrewarmedLanguages = Set<String>()
    private var ttsPrewarmCompleted = false
    
    // AudioUnit output warmup scheduling (runs on audioQueue)
    private var ttsOutputWarmupScheduled: Bool = false
    private var ttsOutputWarmupWorkItem: DispatchWorkItem?
    
    // Box AVFoundation objects to satisfy Swift 6 sendability in completion closures.
    // This object is only ever used for stopping the warmup engine/node.
    private final class WarmupHandles: @unchecked Sendable {
        let engine: AVAudioEngine
        let player: AVAudioPlayerNode
        init(engine: AVAudioEngine, player: AVAudioPlayerNode) {
            self.engine = engine
            self.player = player
        }
    }
    
    // Language Detection
    private let languageRecognizer = NLLanguageRecognizer()
    
    override init() {
        super.init()
        // Default to user's preferred locale or fallback
        let localeId = Locale.preferredLanguages.first ?? Locale.current.identifier
        let locale = Locale(identifier: localeId)
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.speechRecognizer?.delegate = self
        self.synthesizer.delegate = self
        logger.debug("Speech recognizer locale set to \(locale.identifier, privacy: .public)")
        
        // NOTE:
        // Don't activate/prepare audio session in init.
        // This can trigger first-launch AudioUnit/IPC warnings (IPCAUClient) at app startup.
        // We'll activate on-demand when starting recording or speaking.
        
        // IMPORTANT:
        // Do NOT request Mic/Speech permissions on app launch / onboarding.
        // We request on-demand when the user taps the mic in Daily, so it feels expected.
    }

    var canStartRecording: Bool {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission
        // Allow recording if authorized OR if we haven't asked yet (so we can trigger the prompt).
        // Only disable if explicitly denied or restricted.
        let speechOk = (speech == .authorized || speech == .notDetermined)
        let micOk = (mic == .granted || mic == .undetermined)
        return speechOk && micOk
    }

    /// Ensures Mic + Speech permissions and starts recording if granted.
    /// Returns true if recording started, false if permissions were denied.
    @MainActor
    func ensurePermissionsAndStartRecording() async -> Bool {
        let result = await ensurePermissionsForRecordingIfNeeded()
        guard result.granted else {
            return false
        }
        
        // After system permission alerts, the audio stack can be briefly unstable.
        // Pre-warm the recording audio session and give it a short settling window
        // to avoid a "flash stop" on some devices (notably iPad).
        if result.didPrompt {
            self.audioQueue.async { [weak self] in
                guard let self else { return }
                self.setupRecordingAudioSession(activate: true)
                self.rebuildEngineIfNeeded()
                self.prepareEngineIfNeeded()
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        
        startRecordingInternal()
        return true
    }
    
    /// Ensures Mic + Speech permissions. Returns a flag indicating whether we had to show permission prompts.
    @MainActor
    private func ensurePermissionsForRecordingIfNeeded() async -> (granted: Bool, didPrompt: Bool) {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission

        var didPrompt = false
        // If either permission isn't decided yet, the first mic tap is the right moment to ask.
        if speech == .notDetermined || mic == .undetermined {
            didPrompt = true
            await requestPermissions()
        }

        let speechNow = SFSpeechRecognizer.authorizationStatus()
        let micNow = AVAudioApplication.shared.recordPermission

        if speechNow != .authorized {
            self.error = "Speech recognition not authorized"
            return (false, didPrompt)
        }
        if micNow != .granted {
            self.error = "Microphone access denied"
            return (false, didPrompt)
        }
        return (true, didPrompt)
    }
    
    // MARK: - Configuration
    
    /// Updates the speech recognizer locale when the user changes native language in onboarding
    /// - Parameter localeId: The new locale identifier (e.g., "zh-CN", "en-US")
    func updateLocale(_ localeId: String) {
        let locale = Locale(identifier: localeId)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
        logger.info("Updated speech recognizer locale to \(localeId, privacy: .public)")
    }
    
    /// Configures speech settings to align with onboarding preferences
    /// - Parameters:
    ///   - nativeLocaleId: Optional native language locale identifier
    ///   - preferOnDevice: Whether to prefer on-device recognition
    func configure(nativeLocaleId: String?, preferOnDevice: Bool) {
        if let id = nativeLocaleId {
            updateLocale(id)
        }
        prefersOnDeviceRecognition = preferOnDevice
    }
    
    private func configureAudioSessionIfNeeded(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions,
        activate: Bool
    ) {
        do {
            let session = AVAudioSession.sharedInstance()
            if currentAudioCategory != category || currentAudioMode != mode {
                try session.setCategory(category, mode: mode, options: options)
                currentAudioCategory = category
                currentAudioMode = mode
            }
            // Only set preferred I/O once; reapplying on every mode switch can trigger extra AudioUnit churn.
            if didSetPreferredIO == false {
                try session.setPreferredSampleRate(44_100)
                // 10ms can cause zero-byte buffer warnings on some devices on first activation.
                // 20ms is a safer default and reduces first-play stutter.
                try session.setPreferredIOBufferDuration(0.02)
                didSetPreferredIO = true
            }
            // Only activate once; repeated setActive calls are a common source of AudioUnit churn / stalls.
            // IMPORTANT: do not activate during cold-start/permissions; activation can block and cause launch hitch.
            if activate, isAudioSessionActive == false {
                try session.setActive(true)
                isAudioSessionActive = true
            }
            logger.debug("Audio session prepared category=\(category.rawValue, privacy: .public) mode=\(mode.rawValue, privacy: .public)")
        } catch {
            logger.error("Failed to setup audio session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func setupRecordingAudioSession(activate: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            configureAudioSessionIfNeeded(
                category: .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP],
                activate: activate
            )
            if #available(iOS 13.0, *) {
                try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
            }
        } catch {
            logger.error("Failed to setup recording session: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func setupPlaybackAudioSession(activate: Bool) {
        // Playback should prefer a playback-optimized mode/category.
        // Using `.measurement` can make output feel quieter and can route audio in a suboptimal way
        // (especially with Bluetooth / receiver routing). For TTS, `.spokenAudio` is the best fit.
        configureAudioSessionIfNeeded(
            category: .playback,
            mode: .spokenAudio,
            options: [.duckOthers],
            activate: activate
        )
    }

    /// Prepare audio session/engine ahead of the first user interaction.
    /// Call this IMMEDIATELY on app launch to move unavoidable system warmups off the critical path.
    /// AudioUnit initialization can take 3-5 seconds on first launch - this MUST happen before user interaction.
    func primeAudioSessionForInteraction() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.setupRecordingAudioSession(activate: true)
            self.rebuildEngineIfNeeded()
            self.prepareEngineIfNeeded()
            
            // CRITICAL: Actually start and immediately stop the engine to force AudioUnit graph initialization.
            // This is what takes 3-5 seconds on cold start - better to do it now than when user taps record.
            if self.hasPrewarmed == false {
                self.hasPrewarmed = true
                do {
                    // Install a minimal tap to force the input node to connect
                    let inputNode = self.audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in }
                    try self.audioEngine.start()
                    self.logger.info("Audio engine INPUT primed successfully")
                    // Keep it running briefly to ensure full initialization
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.audioQueue.async { [weak self] in
                            guard let self else { return }
                            self.audioEngine.stop()
                            self.audioEngine.inputNode.removeTap(onBus: 0)
                        }
                    }
                } catch {
                    self.logger.error("Audio engine prime failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
    
    /// Public entry point used right after onboarding.
    /// Requests permissions only if needed, and primes the audio input path when granted.
    @MainActor
    func requestPermissionsAndPrimeIfNeeded() async -> Bool {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission

        if speech == .notDetermined || mic == .undetermined {
            await requestPermissions()
        }

        let speechNow = SFSpeechRecognizer.authorizationStatus()
        let micNow = AVAudioApplication.shared.recordPermission
        let ok = (speechNow == .authorized) && (micNow == .granted)
        if ok {
            // Prime after the user has granted permissions so the first recording is stable.
            primeAudioSessionForInteraction()
        }
        return ok
    }

    @MainActor
    private func requestPermissions() async {
        // Request speech authorization using nonisolated helper to avoid MainActor conflicts
        let speechStatus = await Self.requestSpeechAuthorization()
        
        await MainActor.run {
            switch speechStatus {
            case .authorized:
                logger.info("Speech authorization granted")
                break
            case .denied, .restricted, .notDetermined:
                self.error = "Speech recognition not authorized"
                logger.error("Speech authorization failed: \(String(describing: speechStatus), privacy: .public)")
            @unknown default:
                self.error = "Unknown authorization status"
                logger.error("Speech authorization unknown status")
            }
        }
        
        // Request microphone permission using nonisolated helper
        let micAllowed = await Self.requestMicrophonePermission()
        await MainActor.run {
            if !micAllowed {
                self.error = "Microphone access denied"
                logger.error("Microphone permission denied")
            }
        }
        
        // IMPORTANT: Do not prewarm/activate audio session automatically here.
        // Permission prompts often happen on cold start; activating AudioUnit/IPC can cause a visible launch hitch.
    }
    
    // MARK: - Nonisolated Permission Helpers
    // These must be nonisolated and static to avoid MainActor isolation issues
    // when the system callbacks run on background threads
    
    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    private static func requestMicrophonePermission() async -> Bool {
        return await AVAudioApplication.requestRecordPermission()
    }
    
    func startRecording() {
#if targetEnvironment(simulator)
        // Simulator lacks real mic; provide a safe stub to avoid crashes
        transcript = "（模拟器录音占位）"
        isRecording = false
        audioLevel = 0
        logger.notice("Simulator recording stub returned placeholder transcript")
        return
#else
        // Permission prompt should happen here (Daily mic tap), not earlier.
        // This method is kept for backward compatibility, but new code should use
        // ensurePermissionsAndStartRecording() which returns permission status.
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.ensurePermissionsAndStartRecording()
        }
#endif
    }

    /// Starts recording after permissions are granted.
    /// Keep this split so we can delay system prompts until the user intent is clear.
    private func startRecordingInternal() {
        // If we're speaking, stop immediately before grabbing the mic.
        DispatchQueue.main.async { [weak self] in
            self?.synthesizer.stopSpeaking(at: .immediate)
        }

        Task { @MainActor in
        transcript = ""
        error = nil
        detectedLanguage = nil
        languageRecognizer.reset()
        }
        
        audioQueue.async { [weak self] in
            guard let self else { return }
            // User is interacting: cancel any pending TTS output warmup so recording isn't blocked.
            self.ttsOutputWarmupWorkItem?.cancel()
            self.ttsOutputWarmupWorkItem = nil
            self.ttsOutputWarmupScheduled = false

            let startNs = DispatchTime.now().uptimeNanoseconds
            self.lastRecordPressNs = startNs
            self.lastRecordingStartNs = startNs
            // If user taps quickly, restart cleanly instead of ignoring (prevents tap/task buildup).
            if self.state != .idle {
                self.logger.debug("Restart recording requested; current state: \(String(describing: self.state), privacy: .public)")
                self.stopAndResetInternal()
            }
        
            guard let speechRecognizer = self.speechRecognizer, speechRecognizer.isAvailable else {
                Task { @MainActor in
                    self.error = "Speech recognizer unavailable for locale"
                }
                self.logger.error("Recognizer unavailable for locale or not set")
                return
            }
            
            self.state = .starting
            self.didReceiveNonEmptyAudioBuffer = false
            
            self.setupRecordingAudioSession(activate: true)
            self.rebuildEngineIfNeeded()
            self.prepareEngineIfNeeded()
        
        // Cancel existing task immediately
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
        
        // Create recognition request
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
        
        if #available(iOS 13, *) {
                request.requiresOnDeviceRecognition = self.prefersOnDeviceRecognition && speechRecognizer.supportsOnDeviceRecognition
                self.logger.debug("On-device recognition requested: \(self.prefersOnDeviceRecognition, privacy: .public), supported: \(speechRecognizer.supportsOnDeviceRecognition, privacy: .public)")
        }
        
            self.recognitionRequest = request
            
            let inputNode = self.audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Start recognition task
            self.recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            
                // Extract Sendable values before hopping to MainActor
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let errorDescription = error?.localizedDescription
                
                Task { @MainActor [weak self, text, isFinal, errorDescription] in
                    guard let self else { return }
                    
                    if let text {
                        self.transcript = text
                    self.logger.debug("Transcript update: \(text, privacy: .public), isFinal: \(isFinal)")
                    
                    self.languageRecognizer.processString(text)
                    if let lang = self.languageRecognizer.dominantLanguage {
                        self.detectedLanguage = lang.rawValue
                        self.logger.debug("Detected language: \(lang.rawValue, privacy: .public)")
                    }
                }
                
                    if let errorDescription {
                        // "No speech detected" is very common when the system decides the utterance ended,
                        // even if we already have partial text. Treat it as a soft-finish to avoid
                        // a confusing error UX and repeated restarts.
                        let isNoSpeech = errorDescription.localizedCaseInsensitiveContains("No speech detected")
                        if isNoSpeech, (self.transcript.isEmpty == false) {
                            self.logger.debug("Recognition ended (no-speech) with partial transcript; finishing.")
                            self.stopRecording()
                            return
                        }

                        // If we never got any real audio buffers, surface a clearer hint.
                        if isNoSpeech, self.didReceiveNonEmptyAudioBuffer == false {
                            // Immediately after permissions dialogs or audio session switches, the first recognition
                            // session can report "No speech detected" before we receive any real audio buffers.
                            // Give a short grace window to avoid a confusing flash-stop.
                            let nowNs = DispatchTime.now().uptimeNanoseconds
                            let elapsedMs = Double(nowNs &- self.lastRecordingStartNs) / 1_000_000.0
                            if elapsedMs < 650 {
                                self.logger.debug("Ignoring early no-speech (<650ms) while waiting for audio buffers")
                                return
                            }

                            self.error = "No speech detected"
                            self.logger.error("Recognition error (no audio buffers): \(errorDescription, privacy: .public)")
                            self.stopRecording()
                            return
                        }

                        self.error = errorDescription
                        self.logger.error("Recognition error: \(errorDescription, privacy: .public)")
                        self.stopRecording()
                } else if isFinal {
                    self.stopRecording()
                }
            }
        }
        
        // Install audio tap
            let tapHandler = SpeechManager.makeTapHandler(
                manager: self,
                request: request,
                oneWordModeEnabled: self.oneWordModeEnabled,
                oneWordSilenceDurationNs: self.oneWordSilenceDurationNs,
                oneWordStartThreshold: self.oneWordStartThreshold,
                oneWordSilenceThreshold: self.oneWordSilenceThreshold
            )
            inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat, block: tapHandler)
        
        do {
                try self.audioEngine.start()
                self.state = .recording
                Task { @MainActor in
                    self.isRecording = true
                }
                if let t0 = self.lastRecordPressNs {
                    let dtMs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000.0
                    self.logger.info("Audio engine started (tap->start \(dtMs, format: .fixed(precision: 1))ms)")
                } else {
                    self.logger.info("Audio engine started")
                }
        } catch {
                Task { @MainActor in
            self.error = "Engine Start Error: \(error.localizedDescription)"
                }
                self.logger.error("Audio engine start error: \(error.localizedDescription, privacy: .public)")
                self.state = .idle
            }
        }
    }
    
    func stopRecording() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            guard self.state == .recording || self.state == .starting else {
                return
            }
            self.stopAndResetInternal()
        }
    }
    
    /// Must be called on `audioQueue`.
    private func stopAndResetInternal() {
        self.state = .stopping

        // Signal end of audio to speech recognizer FIRST (non-blocking)
        self.recognitionRequest?.endAudio()

        // Clean up audio engine and task
        // Stability > micro-latency: always stop the engine and remove the tap.
        if self.audioEngine.isRunning {
            self.audioEngine.stop()
        }
        self.audioEngine.inputNode.removeTap(onBus: 0)
        
        // IMPORTANT: Reset the engine to clear any internal state confusion between sessions.
        // This is critical when switching between TTS (playback) and Recognition (input).
        self.audioEngine.reset()

        // Finish the task gracefully (less error spam than cancel).
        self.recognitionTask?.finish()
        self.recognitionTask?.cancel()

        self.recognitionRequest = nil
        self.recognitionTask = nil

        Task { @MainActor in
            self.isRecording = false
        }

        self.state = .idle

        // If output warmup was canceled due to user interaction, try again shortly after.
        if self.ttsPrewarmCompleted == false {
            self.scheduleAudioOutputWarmup(afterSeconds: 0.8)
        }
    }
    // MARK: - Text to Speech
    
    /// Speaks the provided text using native TTS
    /// - Parameters:
    ///   - text: The text to speak
    ///   - language: The language code for TTS voice (default: "en-US")
    func speak(_ text: String, language: String = "en-US") {
        lastSpeakRequestNs = DispatchTime.now().uptimeNanoseconds

        // Capture Sendable primitives only. Build AVSpeechUtterance on main.
        let textCopy = text
        let languageCopy = language

        // IMPORTANT:
        // After a recording session, the active audio session is typically `.playAndRecord + .measurement`,
        // which can make TTS output *feel* much quieter. Always ensure playback settings before speaking.
        let needsPlaybackReconfigure = (currentAudioCategory != .playback) || (currentAudioMode != .spokenAudio)
        if isAudioSessionActive, needsPlaybackReconfigure == false {
            DispatchQueue.main.async { [weak self, textCopy, languageCopy] in
                guard let self else { return }
                // AVSpeechUtterance is not thread-safe / not Sendable.
                let u = AVSpeechUtterance(string: textCopy)
                u.voice = AVSpeechSynthesisVoice(language: languageCopy)
                u.rate = self.speechRate
                u.pitchMultiplier = 1.0
                u.volume = 1.0
                u.preUtteranceDelay = 0
                u.postUtteranceDelay = 0
                self.synthesizer.speak(u)
            }
            return
        }

        // First-time: ensure audio session is active BEFORE calling speak.
        audioQueue.async { [weak self, textCopy, languageCopy] in
            guard let self else { return }
            self.setupPlaybackAudioSession(activate: true)
            DispatchQueue.main.async { [weak self, textCopy, languageCopy] in
                guard let self else { return }
                // Rebuild utterance on main to avoid capturing non-Sendable AV types.
                let u = AVSpeechUtterance(string: textCopy)
                u.voice = AVSpeechSynthesisVoice(language: languageCopy)
                u.rate = self.speechRate
                u.pitchMultiplier = 1.0
                u.volume = 1.0
                u.preUtteranceDelay = 0
                u.postUtteranceDelay = 0
                self.synthesizer.speak(u)
            }
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        if let t0 = lastSpeakRequestNs {
            let dtMs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000.0
            logger.info("TTS didStart (request->start \(dtMs, format: .fixed(precision: 1))ms)")
        }
        lastSpeakRequestNs = nil
    }

    /// Pre-warm the AudioUnit OUTPUT path to eliminate first-play stutter.
    ///
    /// This is intentionally scheduled (not executed immediately) so it doesn't block
    /// the first user-initiated recording on cold start.
    func prewarmAudioOutput() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            guard self.ttsPrewarmCompleted == false else {
                self.logger.debug("AudioUnit output already prewarmed, skipping")
                return
            }
            // Avoid double-scheduling.
            guard self.ttsOutputWarmupScheduled == false else { return }

            self.scheduleAudioOutputWarmup(afterSeconds: 1.0)
        }
    }

    /// Must be called on `audioQueue`.
    private func scheduleAudioOutputWarmup(afterSeconds delay: TimeInterval) {
        guard ttsPrewarmCompleted == false else { return }

        // Cancel any pending warmup and reschedule.
        ttsOutputWarmupWorkItem?.cancel()

        ttsOutputWarmupScheduled = true
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.ttsOutputWarmupWorkItem = nil
            self.ttsOutputWarmupScheduled = false

            // Never warm output while starting/recording; retry shortly after.
            guard self.state == .idle else {
                self.scheduleAudioOutputWarmup(afterSeconds: 1.0)
                return
            }

            // Run the expensive AudioUnit bring-up off the interaction queue.
            self.warmupQueue.async { [weak self] in
                self?.performAudioOutputWarmup()
            }
        }

        ttsOutputWarmupWorkItem = item
        audioQueue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Must be called on `audioQueue`.
    private func performAudioOutputWarmup() {
        guard ttsPrewarmCompleted == false else { return }

        let t0 = DispatchTime.now().uptimeNanoseconds
        // Keep AudioSession bookkeeping on audioQueue (these vars are mutated there).
        audioQueue.sync { [weak self] in
            self?.setupPlaybackAudioSession(activate: true)
        }

        // Create a dedicated AVAudioEngine for output warmup.
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let handles = WarmupHandles(engine: engine, player: player)

        // Connect player to main mixer (forces output graph initialization).
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Create a short silence buffer (~0.15s) long enough to complete IPC handshake.
        let frameCount = AVAudioFrameCount(6_615)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            logger.error("Failed to create silence buffer for warmup")
            return
        }
        buffer.frameLength = frameCount

        do {
            try engine.start()
            player.play()
            // Mark completion on audioQueue (no AV types cross queues).
            audioQueue.async { [weak self] in
                self?.ttsPrewarmCompleted = true
            }

            let t1 = DispatchTime.now().uptimeNanoseconds
            let startMs = Double(t1 - t0) / 1_000_000.0
            logger.info("AudioUnit output warmup: engine started (\(startMs, format: .fixed(precision: 1))ms)")

            player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
                let t2 = DispatchTime.now().uptimeNanoseconds
                let totalMs = Double(t2 - t0) / 1_000_000.0
                Logger(subsystem: "com.angyee.voxwords", category: "speech")
                    .info("AudioUnit OUTPUT warmup completed (\(totalMs, format: .fixed(precision: 1))ms)")
                // IMPORTANT:
                // This completion runs on AVAudioPlayerNode's internal completion queue.
                // Calling `stop()` synchronously here can deadlock inside AVFAudio (dispatch_sync).
                // Always hop to our warmup queue before stopping.
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.05) {
                    handles.player.stop()
                    handles.engine.stop()
                    Logger(subsystem: "com.angyee.voxwords", category: "speech")
                        .debug("AudioUnit output warmup engine stopped")
                }
            }
        } catch {
            logger.error("AudioUnit output warmup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Pre-warm TTS voice for a specific language.
    /// Call this AFTER prewarmAudioOutput() has completed.
    func prewarmTTS(language: String) {
        guard ttsPrewarmedLanguages.contains(language) == false else { return }
        ttsPrewarmedLanguages.insert(language)

        // Delay TTS warmup to ensure AudioUnit output is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            // Use a very short utterance and let it complete naturally (NO stopSpeaking!)
            let u = AVSpeechUtterance(string: ".")
            u.voice = AVSpeechSynthesisVoice(language: language)
            u.rate = AVSpeechUtteranceMaximumSpeechRate
            u.pitchMultiplier = 1.0
            u.volume = 0.0 // Now safe because AudioUnit output is already warmed
            u.preUtteranceDelay = 0
            u.postUtteranceDelay = 0
            self.synthesizer.speak(u)
            self.logger.debug("TTS voice prewarm started for \(language, privacy: .public)")
        }
    }
    
    private func prepareEngineIfNeeded() {
        if !audioEngine.isRunning {
            audioEngine.prepare()
        }
    }
    
    private func prewarmIfNeeded() {
#if targetEnvironment(simulator)
        return
#else
        guard !hasPrewarmed else { return }
        guard state == .idle else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        
        hasPrewarmed = true
        
        // Only set up category/mode and preferred I/O; do NOT activate during prewarm.
        setupRecordingAudioSession(activate: false)
        rebuildEngineIfNeeded()
        prepareEngineIfNeeded()
        // NOTE: Do not start a dummy recognition task here. That pattern often causes
        // noisy system audio logs and can destabilize the first real session on device.
        _ = recognizer
#endif
    }
    
    private func rebuildEngineIfNeeded() {
        // If the graph lost its input/output nodes (seen in crash logs), rebuild engine.
        let hasInput = audioEngine.inputNode.engine != nil
        let hasOutput = audioEngine.outputNode.engine != nil
        if !hasInput || !hasOutput {
            audioEngine.stop()
            audioEngine.reset()
            audioEngine = AVAudioEngine()
        }
    }
    
    // MARK: - Audio Tap Handler
    
    /// Creates a nonisolated tap handler for the audio engine
    /// This must be nonisolated because AVAudioEngine's installTap runs on a real-time audio thread
    /// - Parameters:
    ///   - manager: Weak reference to the SpeechManager instance
    ///   - request: The speech recognition request to append audio buffers to
    /// - Returns: A block that processes audio buffers
    private static func makeTapHandler(
        manager: SpeechManager,
        request: SFSpeechAudioBufferRecognitionRequest,
        oneWordModeEnabled: Bool,
        oneWordSilenceDurationNs: UInt64,
        oneWordStartThreshold: Float,
        oneWordSilenceThreshold: Float
    ) -> (AVAudioPCMBuffer, AVAudioTime) -> Void {
        final class TapState {
            var heardVoice: Bool = false
            var lastNonSilentNs: UInt64 = 0
            var requestedStop: Bool = false
            // Throttle UI updates to avoid flooding MainActor (which can delay translation callbacks).
            var lastUIUpdateNs: UInt64 = 0
        }
        let tapState = TapState()
        // Use a local throttler state if possible, or just accept MainActor hopping cost (it's lower without allocation)
        // Since this is a static creator, we can't easily capture mutable state without a class wrapper.
        // We will rely on lightweight calculation.
        
        return { [weak manager] buffer, _ in
            // Append audio buffer to recognition request
            guard buffer.frameLength > 0 else { return }
            manager?.didReceiveNonEmptyAudioBuffer = true
            request.append(buffer)
            
            // Calculate audio level for visualization
            guard let manager = manager,
                  let channelData = buffer.floatChannelData else { return }
            
            let channelDataValue = channelData.pointee
            let frameLength = Int(buffer.frameLength)
            let stride = buffer.stride
            
            // Optimization: Avoid Array allocation (.map) in audio callback
            var sum: Float = 0
            // Process every 4th sample to reduce CPU usage further (downsampling for viz is fine)
            let step = stride * 4
            var count = 0
            
            for i in Swift.stride(from: 0, to: frameLength, by: step) {
                let sample = channelDataValue[i]
                sum += sample * sample
                count += 1
            }
            
            guard count > 0 else { return }
            
            let rms = sqrt(sum / Float(count))
            let avgPower = 20 * log10(rms)
            let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
            
            // Update audio level on MainActor, but THROTTLED.
            // The audio tap can run ~40-100 times/sec; spamming MainActor here can starve other UI work
            // (including Translation.framework callbacks), which looks like "stuck on translating until navigating away".
            let nowNs = DispatchTime.now().uptimeNanoseconds
            let uiIntervalNs: UInt64 = 33_000_000 // ~30 FPS
            if nowNs &- tapState.lastUIUpdateNs >= uiIntervalNs {
                tapState.lastUIUpdateNs = nowNs
                Task { @MainActor in
                    manager.audioLevel = normalizedLevel
                }
            }

            // One-word mode: auto-stop after we detect speech followed by silence.
            guard oneWordModeEnabled else { return }
            if tapState.requestedStop { return }

            let now = nowNs

            if normalizedLevel >= oneWordStartThreshold {
                tapState.heardVoice = true
                tapState.lastNonSilentNs = now
            } else if tapState.heardVoice {
                if normalizedLevel >= oneWordSilenceThreshold {
                    tapState.lastNonSilentNs = now
                } else {
                    if now > tapState.lastNonSilentNs,
                       now - tapState.lastNonSilentNs > oneWordSilenceDurationNs {
                        tapState.requestedStop = true
                        manager.logger.debug("Auto-stop (one-word) triggered by silence")
                        manager.audioQueue.async { [weak manager] in
                            manager?.stopRecording()
                        }
                    }
                }
            }
        }
    }
}

// Allow use in @Sendable closures guarded by internal queue/state.
extension SpeechManager: @unchecked Sendable {}

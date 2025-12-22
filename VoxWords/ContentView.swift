import SwiftUI
import SwiftData

/// Main view for the VoxWords app
/// Handles speech recording, vocabulary card generation, and display
struct ContentView: View {
    // MARK: - Language Preferences
    @AppStorage("nativeLanguage") private var nativeLanguage: String = "zh-CN"
    @AppStorage("targetLanguage") private var targetLanguage: String = "en-US"
    
    // MARK: - State
    @ObservedObject private var speechManager: SpeechManager
    @ObservedObject private var store: AppStore
    @State private var isRecording = false
    @State private var currentTranscript = ""
    
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var path: [Route] = []
    @State private var didAutoLaunchToToday: Bool = false
    @State private var showSettings: Bool = false
    @State private var enableZoomTransition: Bool = false
    @State private var showPaywall: Bool = false

    // Paywall gating (simple + mainstream): allow some value, then gate "save".
    @AppStorage("totalConfirmedCards") private var totalConfirmedCards: Int = 0
    private let freeCardLimit: Int = 6

    @Namespace private var navZoomNS
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var purchase: PurchaseManager
    @Query(sort: \WordEntry.createdAt, order: .reverse) private var entries: [WordEntry]
    
    init(speechManager: SpeechManager, store: AppStore) {
        self.speechManager = speechManager
        self.store = store
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            let isHomeActive = path.isEmpty
            HomeView(
                selectedDay: $selectedDay,
                entries: entries,
                isActive: isHomeActive,
                zoomNamespace: navZoomNS,
                onOpenDay: { day in
                    HapticManager.shared.softImpact()
                    enableZoomTransition = true
                    path.append(.day(day))
                },
                onOpenSettings: {
                    showSettings = true
                }
            )
            .background(LiquidGlassBackground().ignoresSafeArea())
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .day(let day):
                    let daily = DailyDeckView(
                        selectedDay: $selectedDay,
                        initialDay: day,
                        entries: entries,
                        previewCard: Binding(
                            get: { store.previewCard },
                            set: { store.previewCard = $0 }
                        ),
                        isRecording: $isRecording,
                        currentTranscript: $currentTranscript,
                        audioLevel: { speechManager.audioLevel },
                        onStartRecording: {
                            store.dismissPreview()
                            currentTranscript = ""
                            speechManager.startRecording()
                        },
                        onStopRecording: {
                            Task { speechManager.stopRecording() }
                        },
                        onSpeak: { word, language in
                            speechManager.speak(word, language: language)
                        },
                        onDeleteEntry: { id in
                            deleteEntry(id: id)
                        },
                        onConfirm: { card in
                            confirm(card)
                        },
                        onDismissPreview: {
                            store.dismissPreview()
                        },
                        onRetry: { card in
                            Task { await store.retryIfPossible() }
                        },
                        onBack: {
                            HapticManager.shared.softImpact()
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.90)) {
                                if path.isEmpty == false { path.removeLast() }
                            }
                        }
                    )
                    .background(LiquidGlassBackground().ignoresSafeArea())
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
                    
                    // IMPORTANT:
                    // When we auto-launch into Daily at cold start, the Home matched source isn't laid out yet.
                    // Applying a zoom transition in that state causes the "first-entry wobble" you observed.
                    // Only enable zoom transitions for user-initiated navigation (tap on a day card).
                    if enableZoomTransition {
                        daily.navigationTransition(.zoom(sourceID: Calendar.current.startOfDay(for: day), in: navZoomNS))
                    } else {
                        daily
                    }
                }
            }
            .onChange(of: speechManager.transcript) { _, newValue in
                currentTranscript = newValue
            }
            .onChange(of: speechManager.isRecording, initial: false) { oldValue, newValue in
                if newValue == false { isRecording = false }
                guard oldValue == true, newValue == false else { return }
                let transcript = speechManager.transcript
                guard transcript.isEmpty == false else { return }
                Task(priority: .userInitiated) {
                    await store.handleSpeechFinal(transcript)
                }
            }
            .onAppear {
                speechManager.configure(nativeLocaleId: nativeLanguage, preferOnDevice: true)
                selectedDay = Calendar.current.startOfDay(for: Date())
                
                // Set language pair to trigger translation warmup
                store.setLanguagePair(native: nativeLanguage, target: targetLanguage)

                // Default entry: jump into today's Daily once per app launch.
                if didAutoLaunchToToday == false {
                    didAutoLaunchToToday = true
                    // Delay one runloop so Home finishes first layout, then push WITHOUT zoom transition.
                    Task { @MainActor in
                        enableZoomTransition = false
                        await Task.yield()
                        var t = Transaction()
                        t.animation = nil
                        withTransaction(t) {
                            path.append(.day(selectedDay))
                        }
                    }
                }
            }
            .onChange(of: nativeLanguage) { _, newValue in
                speechManager.configure(nativeLocaleId: newValue, preferOnDevice: true)
                store.setLanguagePair(native: newValue, target: targetLanguage)
            }
            .onChange(of: targetLanguage) { _, newValue in
                // Prewarm TTS immediately when target language changes
                speechManager.prewarmTTS(language: newValue)
                store.setLanguagePair(native: nativeLanguage, target: newValue)
            }
        }
    }

    enum Route: Hashable {
        case day(Date)
    }

    // MARK: - Daily deck (one-day-per-screen, bottom-peek paging)
    private struct DailyDeckView: View {
        @Binding var selectedDay: Date
        let initialDay: Date
        let entries: [WordEntry]

        @Binding var previewCard: VocabularyCard?
        @Binding var isRecording: Bool
        @Binding var currentTranscript: String

        let audioLevel: () -> Float
        let onStartRecording: () -> Void
        let onStopRecording: () -> Void
        let onSpeak: (String, String) -> Void
        let onDeleteEntry: (UUID) -> Void
        let onConfirm: (VocabularyCard) -> Void
        let onDismissPreview: () -> Void
        let onRetry: (VocabularyCard) -> Void
        let onBack: () -> Void

        @State private var currentDay: Date
        // Note: we keep the interaction simple & stable: horizontal paging between days.

        private var cal: Calendar { Calendar.current }

        init(
            selectedDay: Binding<Date>,
            initialDay: Date,
            entries: [WordEntry],
            previewCard: Binding<VocabularyCard?>,
            isRecording: Binding<Bool>,
            currentTranscript: Binding<String>,
            audioLevel: @escaping () -> Float,
            onStartRecording: @escaping () -> Void,
            onStopRecording: @escaping () -> Void,
            onSpeak: @escaping (String, String) -> Void,
            onDeleteEntry: @escaping (UUID) -> Void,
            onConfirm: @escaping (VocabularyCard) -> Void,
            onDismissPreview: @escaping () -> Void,
            onRetry: @escaping (VocabularyCard) -> Void,
            onBack: @escaping () -> Void
        ) {
            self._selectedDay = selectedDay
            self.initialDay = initialDay
            self.entries = entries
            self._previewCard = previewCard
            self._isRecording = isRecording
            self._currentTranscript = currentTranscript
            self.audioLevel = audioLevel
            self.onStartRecording = onStartRecording
            self.onStopRecording = onStopRecording
            self.onSpeak = onSpeak
            self.onDeleteEntry = onDeleteEntry
            self.onConfirm = onConfirm
            self.onDismissPreview = onDismissPreview
            self.onRetry = onRetry
            self.onBack = onBack

            let d = Calendar.current.startOfDay(for: initialDay)
            self._currentDay = State(initialValue: d)
        }

        /// Ordered days: today (even if empty) + days that have entries.
        private func daysWithWords(include day: Date) -> [Date] {
            let today = cal.startOfDay(for: Date())
            let required = cal.startOfDay(for: day)
            let all = Set(entries.map { cal.startOfDay(for: $0.createdAt) })
                .union([today, required])
            // Only keep today (even if empty) + days that have entries.
            let filtered = all.filter { d in
                if d == today { return true }
                return entries.contains(where: { cal.startOfDay(for: $0.createdAt) == d })
            }
            return filtered.sorted(by: >) // newest -> oldest
        }

        private func cards(for day: Date) -> [VocabularyCard] {
            let dayKey = cal.startOfDay(for: day)
            let dayEntries = entries
                .filter { cal.startOfDay(for: $0.createdAt) == dayKey }
                .sorted(by: { $0.createdAt > $1.createdAt })

            var seen = Set<UUID>()
            let unique = dayEntries.filter { e in
                guard seen.contains(e.id) == false else { return false }
                seen.insert(e.id)
                return true
            }

            return unique.map { e in
                VocabularyCard(
                    id: e.id,
                    word: e.targetText,
                    translation: e.nativeText,
                    nativeLanguage: e.nativeLanguage,
                    targetLanguage: e.targetLanguage,
                    imageURL: nil,
                    audioURL: nil,
                    soundEffectURL: nil,
                    sceneNote: nil,
                    category: nil,
                    status: .complete,
                    createdAt: e.createdAt
                )
            }
        }

        var body: some View {
            let days = daysWithWords(include: initialDay)
            let headerDay = cal.startOfDay(for: currentDay)
            let headerHeight: CGFloat = 140

            ZStack(alignment: .topLeading) {
                TabView(selection: $currentDay) {
                    ForEach(days, id: \.self) { d in
                        DayPage(
                            day: cal.startOfDay(for: d),
                            headerHeight: headerHeight,
                            cards: { dd in cards(for: dd) },
                            onSpeak: onSpeak,
                            onDelete: onDeleteEntry
                        )
                        .tag(cal.startOfDay(for: d))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onAppear {
                    // Avoid first-frame layout jitter by ensuring state is already set from init,
                    // and only syncing the binding here (no animation).
                    let d = cal.startOfDay(for: initialDay)
                    if selectedDay != d {
                        var t = Transaction()
                        t.animation = nil
                        withTransaction(t) { selectedDay = d }
                    }
                }
                .onChange(of: currentDay) { _, newValue in
                    let d = cal.startOfDay(for: newValue)
                    if selectedDay != d {
                        HapticManager.shared.selectionChanged()
                        selectedDay = d
                    }
                }
                // Left-edge swipe-back (like system interactive pop).
                .overlay(alignment: .leading) {
                    Color.clear
                        .frame(width: 26)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                                .onEnded { value in
                                    guard previewCard == nil, isRecording == false else { return }
                                    let dx = value.translation.width
                                    let dy = value.translation.height
                                    // Must start very close to edge so it doesn't fight the horizontal pager.
                                    guard value.startLocation.x < 18 else { return }
                                    guard abs(dy) < 26 else { return }
                                    guard dx > 140, abs(dx) > abs(dy) * 2.4 else { return }
                                    HapticManager.shared.selectionChanged()
                                    onBack()
                                }
                        )
                }

                // Fixed header under back button (top-left, always).
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.75))
                            .padding(10)
                            .glassIconCircle(size: 44)
                    }
                    .buttonStyle(.plain)

                    Text(headerDay, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 44, weight: .regular, design: .serif))
                        .foregroundStyle(.primary.opacity(0.92))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: headerDay)

                    Text(String.localizedStringWithFormat(String(localized: "common.words_count"), cards(for: headerDay).count))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                .safeAreaPadding(.top, 8)

                if isRecording {
                    ZStack {
                        Color.primary.opacity(0.10).ignoresSafeArea()
                        VStack(spacing: 16) {
                            VStack(spacing: 10) {
                                Text(currentTranscript.isEmpty ? String(localized: "daily.listening") : currentTranscript)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(VoxTheme.Colors.deepBrown)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.white)
                                            .shadow(color: VoxTheme.Shadows.card, radius: 10, y: 5)
                                    )
                                Text(String(localized: "daily.release_to_generate"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            VisualizerView(audioLevel: audioLevel(), isRecording: isRecording)
                                .frame(height: 60)
                                .padding(.horizontal, 50)
                        }
                        .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if let c = previewCard {
                    RetroPreviewCard(
                        card: c,
                        // Enable retry for all error-like terminal states (localized).
                        isFailure: c.translation.contains(String(localized: "translation.failed"))
                            || c.translation.contains(String(localized: "translation.timeout"))
                            || c.translation.contains(String(localized: "translation.service_starting"))
                            || c.translation.contains(String(localized: "translation.need_language_pack"))
                            || c.translation.contains(String(localized: "translation.unsupported_pair"))
                            || c.translation.contains(String(localized: "translation.not_ready"))
                            || c.translation.contains(String(localized: "translation.cancelled")),
                        onSpeak: { onSpeak(c.word, c.targetLanguage) },
                        onConfirm: { onConfirm(c) },
                        onDismiss: onDismissPreview,
                        onRetry: { onRetry(c) }
                    )
                    .transition(.opacity)
                }
            }
            // IMPORTANT:
            // Using `safeAreaInset` here causes a second layout pass once safe-area is resolved,
            // which shows up as a "wobble" on first entry. Overlay keeps layout stable.
            .overlay(alignment: .bottom) {
                if previewCard == nil {
                    RecordButton(
                        isRecording: $isRecording,
                        audioLevel: audioLevel(),
                        onRecordingStart: onStartRecording,
                        onRecordingEnd: onStopRecording
                    )
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity)
                    .safeAreaPadding(.bottom, 18)
                }
            }
        }
    }

    private struct DayPage: View {
        let day: Date
        let headerHeight: CGFloat
        let cards: (Date) -> [VocabularyCard]
        let onSpeak: (String, String) -> Void
        let onDelete: (UUID) -> Void

        var body: some View {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: headerHeight)

                    let cs = cards(day)
                    if cs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "daily.empty.title"))
                                .font(.system(size: 34, weight: .regular, design: .serif))
                                .foregroundStyle(.primary.opacity(0.92))
                            Text(String(localized: "daily.empty.hint"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 22)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(Array(cs.enumerated()), id: \.offset) { _, card in
                                RetroWordCard(
                                    card: card,
                                    onSpeak: { onSpeak(card.word, card.targetLanguage) },
                                    onDelete: { onDelete(card.id) }
                                )
                            }
                        }
                    }

                    Spacer(minLength: 180)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VoxTheme.Dimensions.largePadding)
            }
        }
    }
    
    // MARK: - Card Generation
    // Translation flow lives in AppStore.

    @MainActor
    private func confirm(_ card: VocabularyCard) {
        // Prevent confirming while translation is still pending
        if card.status != .complete {
            speechManager.speak(String(localized: "daily.confirm.wait"), language: nativeLanguage)
            return
        }

        // Gate: after the user has created enough cards, require subscription to save.
        if purchase.isPremium == false, totalConfirmedCards >= freeCardLimit {
            HapticManager.shared.selectionChanged()
            showPaywall = true
            return
        }
        HapticManager.shared.mediumImpact()
        let day = Calendar.current.startOfDay(for: Date())
        let entry = WordEntry(
            id: card.id,
            nativeText: card.translation,
            targetText: card.word,
            nativeLanguage: card.nativeLanguage,
            targetLanguage: card.targetLanguage,
            createdAt: Date()
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            totalConfirmedCards &+= 1
        } catch {
            // If persistence fails, don't count it against free quota.
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            selectedDay = day
            store.dismissPreview()
        }
    }

    @MainActor
    private func deleteEntry(id: UUID) {
        if let e = entries.first(where: { $0.id == id }) {
            HapticManager.shared.mediumImpact()
            modelContext.delete(e)
            try? modelContext.save()
        }
    }

}

#Preview {
    ContentView(speechManager: SpeechManager(), store: AppStore())
}

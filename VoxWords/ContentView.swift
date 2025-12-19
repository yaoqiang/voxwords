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
    
    @Environment(\.modelContext) private var modelContext
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
                onOpenDay: { day in
                    HapticManager.shared.selectionChanged()
                    path.append(.day(day))
                },
                onOpenSettings: {
                    showSettings = true
                }
            )
            .background(DotGridBackground().ignoresSafeArea())
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .day(let day):
                    DailyDeckView(
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
                            HapticManager.shared.selectionChanged()
                            if path.isEmpty == false { path.removeLast() }
                        }
                    )
                    .background(DotGridBackground().ignoresSafeArea())
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
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
                    path.append(.day(selectedDay))
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
        let onConfirm: (VocabularyCard) -> Void
        let onDismissPreview: () -> Void
        let onRetry: (VocabularyCard) -> Void
        let onBack: () -> Void

        @State private var currentDay: Date = Calendar.current.startOfDay(for: Date())
        @State private var isPaging: Bool = false
        @State private var scrollTargetId: String? = nil
        @State private var lastPagingCheckNs: UInt64 = 0

        private var cal: Calendar { Calendar.current }

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

        private func previousDayWithWords(from day: Date, days: [Date]) -> Date? {
            let d = cal.startOfDay(for: day)
            guard let idx = days.firstIndex(of: d) else { return nil }
            guard idx + 1 < days.count else { return nil } // older day
            return days[idx + 1]
        }

        private func nextDayWithWords(from day: Date, days: [Date]) -> Date? {
            let d = cal.startOfDay(for: day)
            guard let idx = days.firstIndex(of: d) else { return nil }
            guard idx - 1 >= 0 else { return nil } // newer day
            return days[idx - 1]
        }

        private struct SentinelOffsetsKey: PreferenceKey {
            static let defaultValue: [String: CGFloat] = [:]
            static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
                value.merge(nextValue(), uniquingKeysWith: { $1 })
            }
        }

        var body: some View {
            let days = daysWithWords(include: initialDay)
            let prevDay = previousDayWithWords(from: currentDay, days: days)
            let nextDay = nextDayWithWords(from: currentDay, days: days)
            let headerDay = cal.startOfDay(for: currentDay)
            let headerHeight: CGFloat = 128

            ZStack(alignment: .topLeading) {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            // Top “peek” (newer day). Hidden by default by scrolling to contentTop.
                            if let nextDay {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(nextDay, format: .dateTime.month(.abbreviated).day())
                                        .font(.system(size: 34, weight: .regular, design: .serif))
                                        .foregroundStyle(Color.black.opacity(0.22))
                                    Text("\(cards(for: nextDay).count) Words")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.black.opacity(0.18))
                                }
                                .padding(.top, 4)
                                .id("topPeek")

                                // A real-sized sentinel so viewAligned can actually land on it.
                                Color.clear.frame(height: 80).id("topSentinel")
                                    .background(
                                        GeometryReader { g in
                                            Color.clear.preference(
                                                key: SentinelOffsetsKey.self,
                                                value: ["topSentinel": g.frame(in: .named("dailyDeck")).minY]
                                            )
                                        }
                                    )
                            }

                            // Main content start — always keep this aligned to avoid header/card overlap.
                            Color.clear.frame(height: headerHeight).id("contentTop")

                            let cs = cards(for: headerDay)
                            if cs.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("今天还没有单词")
                                        .font(.system(size: 34, weight: .regular, design: .serif))
                                        .foregroundStyle(Color.black.opacity(0.88))
                                    Text("按住底部麦克风说一个中文词，比如「苹果」\n松手后会生成英文卡片。")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.black.opacity(0.55))
                                }
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                )
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                    ForEach(Array(cs.enumerated()), id: \.offset) { _, card in
                                        RetroWordCard(card: card) { onSpeak(card.word, card.targetLanguage) }
                                    }
                                }
                            }

                            Spacer(minLength: 24)

                            // Bottom peek (older day). This stays within CURRENT day only.
                            if let prevDay {
                                // Sentinel goes BEFORE the peek title so viewAligned can land on it
                                // while the peek title is still visible (natural "keep scrolling to flip").
                                Color.clear
                                    .frame(height: 80)
                                    .id("bottomSentinel")
                                    .background(
                                        GeometryReader { g in
                                            Color.clear.preference(
                                                key: SentinelOffsetsKey.self,
                                                value: ["bottomSentinel": g.frame(in: .named("dailyDeck")).minY]
                                            )
                                        }
                                    )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(prevDay, format: .dateTime.month(.abbreviated).day())
                                        .font(.system(size: 34, weight: .regular, design: .serif))
                                        .foregroundStyle(Color.black.opacity(0.22))
                                    Text("\(cards(for: prevDay).count) Words")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.black.opacity(0.22))
                                }
                                .padding(.top, 18)
                                .padding(.bottom, 140)
                                .id("bottomPeek")
                            } else {
                                Color.clear.frame(height: 140)
                            }
                        }
                        .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                        .scrollTargetLayout()
                    }
                    .coordinateSpace(name: "dailyDeck")
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $scrollTargetId, anchor: .top)
                    // Fallback paging detection: if scrollPosition isn't landing on sentinel on some devices,
                    // this offset-based trigger still works. Throttled to avoid per-frame spam.
                    .onPreferenceChange(SentinelOffsetsKey.self) { offsets in
                        let now = DispatchTime.now().uptimeNanoseconds
                        if now &- lastPagingCheckNs < 100_000_000 { return } // 100ms
                        lastPagingCheckNs = now

                        guard isPaging == false else { return }
                        guard previewCard == nil, isRecording == false else { return }

                        if let y = offsets["bottomSentinel"], y < 260, let prevDay {
                            isPaging = true
                            HapticManager.shared.selectionChanged()
                            onDismissPreview()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                currentDay = prevDay
                                selectedDay = prevDay
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                scrollTargetId = "contentTop"
                                proxy.scrollTo("contentTop", anchor: .top)
                                isPaging = false
                            }
                            return
                        }

                        // Pulling down reveals the top peek; when top sentinel drops enough, page to newer day.
                        if let y = offsets["topSentinel"], y > 40, let nextDay {
                            isPaging = true
                            HapticManager.shared.selectionChanged()
                            onDismissPreview()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                currentDay = nextDay
                                selectedDay = nextDay
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                scrollTargetId = "contentTop"
                                proxy.scrollTo("contentTop", anchor: .top)
                                isPaging = false
                            }
                            return
                        }
                    }
                    .onAppear {
                        let d = cal.startOfDay(for: initialDay)
                        currentDay = d
                        selectedDay = d
                        DispatchQueue.main.async {
                            scrollTargetId = "contentTop"
                            proxy.scrollTo("contentTop", anchor: .top)
                        }
                    }
                    .onChange(of: scrollTargetId) { _, newValue in
                        guard isPaging == false else { return }
                        guard previewCard == nil, isRecording == false else { return }

                        if newValue == "bottomSentinel", let prevDay {
                            isPaging = true
                            HapticManager.shared.selectionChanged()
                            onDismissPreview()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                currentDay = prevDay
                                selectedDay = prevDay
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                                scrollTargetId = "contentTop"
                                proxy.scrollTo("contentTop", anchor: .top)
                                isPaging = false
                            }
                        }

                        if newValue == "topSentinel", let nextDay {
                            isPaging = true
                            HapticManager.shared.selectionChanged()
                            onDismissPreview()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                currentDay = nextDay
                                selectedDay = nextDay
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                                scrollTargetId = "contentTop"
                                proxy.scrollTo("contentTop", anchor: .top)
                                isPaging = false
                            }
                        }
                    }
                }

                // Fixed header under back button (top-left, always).
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.70))
                            .padding(10)
                            .background(Color.white.opacity(0.95))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)

                    Text(headerDay, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 44, weight: .regular, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: headerDay)

                    Text("\(cards(for: headerDay).count) Words")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
                .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                .padding(.top, 8)

                if isRecording {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        VStack(spacing: 16) {
                            VStack(spacing: 10) {
                                Text(currentTranscript.isEmpty ? "正在听…" : currentTranscript)
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
                                Text("松手生成卡片")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.black.opacity(0.45))
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
                        // Enable retry for all error-like terminal states (including timeout / service-warming).
                        isFailure: c.translation.contains("点重试")
                            || c.translation.contains("翻译失败")
                            || c.translation.contains("翻译超时")
                            || c.translation.contains("正在启动")
                            || c.translation.contains("需要下载")
                            || c.translation.contains("不支持")
                            || c.translation.contains("未就绪"),
                        onSpeak: { onSpeak(c.word, c.targetLanguage) },
                        onConfirm: { onConfirm(c) },
                        onDismiss: onDismissPreview,
                        onRetry: { onRetry(c) }
                    )
                    .transition(.opacity)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if previewCard == nil {
                    RecordButton(
                        isRecording: $isRecording,
                        audioLevel: audioLevel(),
                        onRecordingStart: onStartRecording,
                        onRecordingEnd: onStopRecording
                    )
                    .padding(.bottom, 18)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity)
                } else {
                    Color.clear.frame(height: 110)
                }
            }
        }
    }
    
    // MARK: - Card Generation
    // Translation flow lives in AppStore.

    @MainActor
    private func confirm(_ card: VocabularyCard) {
        // Prevent confirming while translation is still pending
        if card.status != .complete {
            speechManager.speak("还在翻译，请稍等～", language: nativeLanguage)
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
        try? modelContext.save()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            selectedDay = day
            store.dismissPreview()
        }
    }

}

#Preview {
    ContentView(speechManager: SpeechManager(), store: AppStore())
}

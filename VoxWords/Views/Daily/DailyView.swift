import SwiftUI

// MARK: - Daily

struct DailyView: View {
    let day: Date
    let entries: [WordEntry]

    @Binding var previewCard: VocabularyCard?
    @Binding var isRecording: Bool
    @Binding var currentTranscript: String

    let audioLevel: () -> Float
    let isRecordEnabled: Bool
    let onPermissionGuide: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onSpeak: (String) -> Void
    let onConfirm: (VocabularyCard) -> Void
    let onDismissPreview: () -> Void
    let onRetry: (VocabularyCard) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    grid
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, VoxTheme.Dimensions.largePadding)
                .padding(.top, 8)
                .padding(.bottom, 26)
            }

            if isRecording {
                recordingOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if let previewCard {
                previewOverlay(card: previewCard)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticManager.shared.selectionChanged()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.70))
                        .padding(8)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 8)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            RecordButton(
                isRecording: $isRecording,
                audioLevel: audioLevel(),
                isEnabled: isRecordEnabled,
                onDisabledTap: onPermissionGuide,
                onRecordingStart: onStartRecording,
                onRecordingEnd: onStopRecording
            )
            .padding(.bottom, 18)
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 44, weight: .regular, design: .serif))
                .foregroundStyle(Color.black.opacity(0.88))
            Text(String.localizedStringWithFormat(String(localized: "common.words_count"), cards.count))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.45))
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var grid: some View {
        if cards.isEmpty {
            Text(String(localized: "daily.empty.hint"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.55))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                // Defensive: avoid duplicate-ID diff corruption.
                ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                    RetroWordCard(card: card) { onSpeak(card.word) }
                }
            }
        }
    }

    private var dayKey: Date { Calendar.current.startOfDay(for: day) }

    private var cards: [VocabularyCard] {
        let dayEntries = entries
            .filter { Calendar.current.startOfDay(for: $0.createdAt) == dayKey }
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

    private var recordingOverlay: some View {
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
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: currentTranscript)
    }

    @ViewBuilder
    private func previewOverlay(card: VocabularyCard) -> some View {
        RetroPreviewCard(
            card: card,
            isFailure: card.translation.contains(String(localized: "translation.failed"))
                || card.translation.contains(String(localized: "translation.timeout"))
                || card.translation.contains(String(localized: "translation.service_starting"))
                || card.translation.contains(String(localized: "translation.need_language_pack"))
                || card.translation.contains(String(localized: "translation.unsupported_pair"))
                || card.translation.contains(String(localized: "translation.not_ready"))
                || card.translation.contains(String(localized: "translation.cancelled")),
            onSpeak: { onSpeak(card.word) },
            onConfirm: { onConfirm(card) },
            onDismiss: onDismissPreview,
            onRetry: { onRetry(card) }
        )
    }
}

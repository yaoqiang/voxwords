import SwiftUI

// MARK: - Retro cards

struct RetroWordCard: View {
    let card: VocabularyCard
    let onSpeak: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var speakBump: Int = 0

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            speakBump &+= 1
            onSpeak()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(card.word)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.bounce, value: speakBump)
                }

                Text(card.translation)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            // Use the app-wide glass surface so Dark Mode stays readable.
            .glassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    HapticManager.shared.mediumImpact()
                    onDelete()
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }
            }
        }
    }
}

struct RetroPreviewCard: View {
    let card: VocabularyCard
    let isFailure: Bool
    let onSpeak: () -> Void
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        // Confirm UI: big centered content + 3 large circular actions.
        ZStack {
            // Liquid glass overlay (consistent with the rest of the app).
            LiquidGlassBackground().ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                // Sticker / image placeholder with glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.93, blue: 0.72).opacity(0.85),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 170
                            )
                        )
                        .frame(width: 280, height: 280)

                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(VoxTheme.Glass.stroke, lineWidth: VoxTheme.Glass.strokeWidth)
                            )
                            .shadow(color: VoxTheme.Glass.shadow, radius: 18, x: 0, y: 12)
                        Image(systemName: isFailure ? "exclamationmark.triangle.fill" : "sparkles")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(.primary.opacity(isFailure ? 0.70 : 0.55))
                    }
                    .frame(width: 140, height: 140)
                }

                // Word + translation (big)
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text(card.word)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            HapticManager.shared.lightImpact()
                            onSpeak()
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .glassIconCircle(size: 44)
                        }
                        .disabled(isFailure)
                        .opacity(isFailure ? 0.45 : 1)
                    }

                    Text(card.translation)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .opacity(isFailure ? 1.0 : 0.95)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Actions
                HStack(spacing: 26) {
                    CircleActionButton(
                        systemName: "arrow.clockwise",
                        enabled: isFailure,
                        style: .secondary
                    ) {
                        HapticManager.shared.mediumImpact()
                        onRetry()
                    }

                    CircleActionButton(
                        systemName: card.status == .complete ? "checkmark" : "clock",
                        enabled: (isFailure == false) && card.status == .complete,
                        style: .primary
                    ) {
                        HapticManager.shared.mediumImpact()
                        onConfirm()
                    }

                    CircleActionButton(
                        systemName: "xmark",
                        enabled: true,
                        style: .secondary
                    ) {
                        HapticManager.shared.lightImpact()
                        onDismiss()
                    }
                }
                .padding(.bottom, 10)

                // Subtle adjust hint (non-interactive for now; purely UX copy like the reference)
                HStack(spacing: 10) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                    Text(String(localized: "preview.adjust_hint"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.secondary.opacity(0.8))
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
        }
    }
}

struct PreviewPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.primary.opacity(0.9))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

private struct CircleActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let systemName: String
    let enabled: Bool
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(VoxTheme.Glass.stroke, lineWidth: VoxTheme.Glass.strokeWidth))
                    .shadow(color: VoxTheme.Glass.shadow, radius: 14, x: 0, y: 12)
                Image(systemName: systemName)
                    .font(.system(size: style == .primary ? 22 : 20, weight: .bold))
                    .foregroundStyle(style == .primary ? Color.primary.opacity(0.9) : Color.secondary)
            }
            .frame(width: style == .primary ? 78 : 68, height: style == .primary ? 78 : 68)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

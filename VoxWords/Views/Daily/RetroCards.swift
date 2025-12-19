import SwiftUI

// MARK: - Retro cards

struct RetroWordCard: View {
    let card: VocabularyCard
    let onSpeak: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            onSpeak()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(card.word)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.86))
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.35))
                }

                Text(card.translation)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.985, green: 0.975, blue: 0.955)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        }
        .buttonStyle(.plain)
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
        // CapWords-inspired confirm UI: big centered content + 3 large circular actions.
        ZStack {
            // Opaque overlay so text never clashes with underlying cards.
            // (We keep a subtle dot-grid texture, but block the content behind.)
            Color.white.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea().opacity(0.85)

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
                            .fill(Color.white.opacity(0.95))
                            .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 12)
                        Image(systemName: isFailure ? "exclamationmark.triangle.fill" : "sparkles")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(Color.black.opacity(isFailure ? 0.45 : 0.30))
                    }
                    .frame(width: 140, height: 140)
                }

                // Word + translation (big)
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Text(card.word)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.86))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            HapticManager.shared.lightImpact()
                            onSpeak()
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.42))
                                .padding(10)
                                .background(Color.white.opacity(0.85))
                                .clipShape(Circle())
                        }
                        .disabled(isFailure)
                        .opacity(isFailure ? 0.45 : 1)
                    }

                    Text(card.translation)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(isFailure ? 0.55 : 0.60))
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
                    Text("Not what you expected? Tap to adjust")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.black.opacity(0.22))
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.35))
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
        .foregroundStyle(Color.black.opacity(0.78))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.04))
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
            Image(systemName: systemName)
                .font(.system(size: style == .primary ? 22 : 20, weight: .bold))
                .foregroundStyle(Color.black.opacity(style == .primary ? 0.65 : 0.45))
                .frame(width: style == .primary ? 78 : 68, height: style == .primary ? 78 : 68)
                .background(Color.white.opacity(style == .primary ? 0.92 : 0.75))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

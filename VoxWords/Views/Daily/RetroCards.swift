import SwiftUI

// MARK: - Retro cards

struct RetroWordCard: View {
    let card: VocabularyCard
    let onSpeak: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var speakBump: Int = 0
    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: {
            // 单击播放音频（恢复原有行为）
            HapticManager.shared.lightImpact()
            speakBump &+= 1
            onSpeak()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Text(card.word)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    
                    // 小喇叭按钮：独立播放音频
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        speakBump &+= 1
                        onSpeak()
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            VoxTheme.Colors.warmPeach.opacity(0.15),
                                            VoxTheme.Colors.softPink.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 18))
                                .foregroundColor(VoxTheme.Colors.warmPeach)
                                .symbolEffect(.bounce.up, value: speakBump)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Text(card.translation)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            // Use the app-wide glass surface so Dark Mode stays readable.
            .glassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
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

    @State private var speakBump: Int = 0
    @State private var isPressed: Bool = false

    var body: some View {
        // Compact preview UI: focused on content with minimal decoration
        ZStack {
            // Liquid glass overlay (consistent with the rest of the app).
            LiquidGlassBackground().ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Compact status indicator (small icon instead of large decoration)
                if isFailure {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(VoxTheme.Colors.error.opacity(0.7))
                        .padding(.bottom, 8)
                }

                // Word + translation (prominent and centered)
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text(card.word)
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            HapticManager.shared.lightImpact()
                            speakBump &+= 1
                            onSpeak()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                VoxTheme.Colors.warmPeach.opacity(0.15),
                                                VoxTheme.Colors.softPink.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)
                                    .scaleEffect(isPressed ? 0.92 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                                
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(VoxTheme.Colors.warmPeach)
                                    .symbolEffect(.bounce.up, value: speakBump)
                                    .scaleEffect(isPressed ? 0.95 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isFailure)
                        .opacity(isFailure ? 0.45 : 1)
                        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                            isPressed = pressing
                        }, perform: {})
                    }

                    Text(card.translation)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .opacity(isFailure ? 1.0 : 0.95)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .glassCard(cornerRadius: 24)

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

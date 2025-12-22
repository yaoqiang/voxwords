import SwiftUI

/// The "Soul" of VoxWords - A buttery smooth record button with
/// WeChat-like responsiveness and a kid-friendly glass feel.
struct RecordButton: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Bindings & Callbacks
    @Binding var isRecording: Bool
    let audioLevel: Float
    let onRecordingStart: () -> Void
    let onRecordingEnd: () -> Void
    
    // MARK: - State
    @State private var isPressed = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    
    // MARK: - Constants
    private let buttonSize: CGFloat = 80
    private let iconSize: CGFloat = 32
    
    // MARK: - Initialization
    init(
        isRecording: Binding<Bool>,
        audioLevel: Float = 0.0,
        onRecordingStart: @escaping () -> Void,
        onRecordingEnd: @escaping () -> Void
    ) {
        self._isRecording = isRecording
        self.audioLevel = audioLevel
        self.onRecordingStart = onRecordingStart
        self.onRecordingEnd = onRecordingEnd
    }
    
    var body: some View {
        let isDark = (colorScheme == .dark)
        let stroke = isDark ? Color.white.opacity(0.22) : VoxTheme.Glass.stroke

        ZStack {
            // Pulse rings (when recording)
            if isRecording {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(VoxTheme.Colors.warmPeach.opacity(0.3), lineWidth: 2)
                        .frame(width: buttonSize, height: buttonSize)
                        .scaleEffect(pulseScale + CGFloat(index) * 0.3)
                        .opacity(pulseOpacity - Double(index) * 0.2)
                }
            }
            
            // Main button
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: buttonSize, height: buttonSize)
                .overlay(
                    Circle()
                        .stroke(stroke, lineWidth: VoxTheme.Glass.strokeWidth)
                )
                .shadow(
                    color: VoxTheme.Glass.shadow,
                    radius: isPressed ? 10 : 16,
                    y: isPressed ? 6 : 10
                )
                .scaleEffect(buttonScale)
                .animation(isPressed ? VoxTheme.Animations.buttonPress : VoxTheme.Animations.buttonRelease, value: isPressed)
                .animation(isRecording ? nil : VoxTheme.Animations.breathing, value: breathingScale)
            
            // Icon (with inset glass to make it feel "filled")
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(stroke.opacity(0.85), lineWidth: 1))
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isDark ? 0.14 : 0.55),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                            .opacity(isDark ? 0.25 : 0.45)
                    )
                    .opacity(isRecording ? 0.95 : 0.90)

                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary.opacity(isDark ? 0.92 : 0.86))
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isRecording)
                    .shadow(color: Color.white.opacity(isDark ? 0.06 : 0.22), radius: 1, x: 0, y: 1)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        startRecording()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    endRecording()
                }
        )
        .onAppear {
            startBreathingAnimation()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonScale: CGFloat {
        if isPressed {
            return 0.9
        } else if isRecording {
            return 1.1
        } else {
            return breathingScale
        }
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        HapticManager.shared.recordingStart()
        isRecording = true
        onRecordingStart()
    }
    
    private func endRecording() {
        HapticManager.shared.recordingSuccess()
        isRecording = false
        onRecordingEnd()
    }
    
    // MARK: - Animations
    
    private func startBreathingAnimation() {
        withAnimation(VoxTheme.Animations.breathing) {
            breathingScale = 1.05
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
            pulseScale = 2.0
            pulseOpacity = 0
        }
    }
    
    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.0
            pulseOpacity = 0.6
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        VoxTheme.Colors.warmCream
            .ignoresSafeArea()
        
        RecordButton(
            isRecording: .constant(false),
            onRecordingStart: { print("Recording started") },
            onRecordingEnd: { print("Recording ended") }
        )
    }
}

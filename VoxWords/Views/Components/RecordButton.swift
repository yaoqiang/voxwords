import SwiftUI

/// The "Soul" of VoxWords - A buttery smooth record button with
/// WeChat-like responsiveness and CapWords-like aesthetics.
struct RecordButton: View {
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
                .fill(VoxTheme.Colors.primaryGradient)
                .frame(width: buttonSize, height: buttonSize)
                .shadow(
                    color: VoxTheme.Shadows.button,
                    radius: isPressed ? VoxTheme.Shadows.buttonRadius / 2 : VoxTheme.Shadows.buttonRadius,
                    y: isPressed ? VoxTheme.Shadows.buttonY / 2 : VoxTheme.Shadows.buttonY
                )
                .scaleEffect(buttonScale)
                .animation(isPressed ? VoxTheme.Animations.buttonPress : VoxTheme.Animations.buttonRelease, value: isPressed)
                .animation(isRecording ? nil : VoxTheme.Animations.breathing, value: breathingScale)
            
            // Icon
            Image(systemName: isRecording ? "waveform" : "mic.fill")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(.white)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isRecording)
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

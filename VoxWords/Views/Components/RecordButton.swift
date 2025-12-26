import SwiftUI

/// The "Soul" of VoxWords - A buttery smooth record button with
/// WeChat-like responsiveness and a kid-friendly glass feel.
struct RecordButton: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Bindings & Callbacks
    @Binding var isRecording: Bool
    let audioLevel: Float
    let isEnabled: Bool
    let onDisabledTap: (() -> Void)?
    let onRecordingStart: () -> Void
    let onRecordingEnd: () -> Void
    
    // MARK: - State
    @State private var isPressed = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var liquidRotation: Double = 0.0
    
    // MARK: - Constants
    private let buttonSize: CGFloat = 80
    private let iconSize: CGFloat = 32
    
    // MARK: - Initialization
    init(
        isRecording: Binding<Bool>,
        audioLevel: Float = 0.0,
        isEnabled: Bool = true,
        onDisabledTap: (() -> Void)? = nil,
        onRecordingStart: @escaping () -> Void,
        onRecordingEnd: @escaping () -> Void
    ) {
        self._isRecording = isRecording
        self.audioLevel = audioLevel
        self.isEnabled = isEnabled
        self.onDisabledTap = onDisabledTap
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
            
            // Main button - single outer circle with glass edge
            ZStack {
                // Liquid flow effect (animated gradient when recording)
                if isRecording {
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    VoxTheme.Colors.warmPeach.opacity(0.15),
                                    VoxTheme.Colors.softPink.opacity(0.12),
                                    VoxTheme.Colors.warmPeach.opacity(0.15),
                                    VoxTheme.Colors.softPink.opacity(0.12)
                                ]),
                                center: .center,
                                angle: .degrees(liquidRotation)
                            )
                        )
                        .frame(width: buttonSize - 4, height: buttonSize - 4)
                        .blur(radius: 8)
                        .opacity(0.6)
                        .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: liquidRotation)
                }
                
                // Glass circle with edge
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        // Glass edge with highlight
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        stroke.opacity(0.8),
                                        stroke,
                                        stroke.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: VoxTheme.Glass.strokeWidth + 0.5
                            )
                    )
                    .overlay(
                        // Top highlight for glass edge
                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isDark ? 0.35 : 0.75),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .topTrailing
                                ),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-45))
                    )
                    .shadow(
                        color: isDark ? Color.black.opacity(0.42) : VoxTheme.Glass.shadow,
                        radius: isPressed ? 10 : 16,
                        y: isPressed ? 6 : 10
                    )
                    .scaleEffect(buttonScale)
                    .animation(isPressed ? VoxTheme.Animations.buttonPress : VoxTheme.Animations.buttonRelease, value: isPressed)
                    .animation(isRecording ? nil : VoxTheme.Animations.breathing, value: breathingScale)
                
                // Icon in center
                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle((isEnabled ? Color.primary : Color.secondary).opacity(isDark ? 0.92 : 0.86))
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isRecording)
                    .shadow(color: Color.white.opacity(isDark ? 0.06 : 0.22), radius: 1, x: 0, y: 1)
            }
        }
        .opacity(isEnabled ? 1.0 : 0.55)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled else {
                        // If disabled, trigger guide on tap
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.selectionChanged()
                            onDisabledTap?()
                        }
                        return
                    }
                    if !isPressed {
                        isPressed = true
                        startRecording()
                    }
                }
                .onEnded { _ in
                    if isEnabled {
                        isPressed = false
                        endRecording()
                    } else {
                        isPressed = false
                    }
                }
        )
        .contentShape(Circle())
        .onAppear {
            startBreathingAnimation()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulseAnimation()
                startLiquidAnimation()
            } else {
                // Important: recording may end externally (speech recognizer final/error, audio interruption)
                // without our gesture receiving `.onEnded`. If we don't reset `isPressed`,
                // the next press won't trigger `startRecording()`.
                isPressed = false
                stopPulseAnimation()
                stopLiquidAnimation()
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            if newValue == false {
                // Make sure we never keep a "pressed" visual state when disabled.
                isPressed = false
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
    
    private func startLiquidAnimation() {
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            liquidRotation = 360
        }
    }
    
    private func stopLiquidAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            liquidRotation = 0
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
            isEnabled: true,
            onDisabledTap: nil,
            onRecordingStart: { print("Recording started") },
            onRecordingEnd: { print("Recording ended") }
        )
    }
}

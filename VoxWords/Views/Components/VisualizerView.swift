import SwiftUI

/// Real-time audio waveform visualizer using Canvas and TimelineView
/// Provides silky-smooth 60fps animation with Metal acceleration
struct VisualizerView: View {
    // MARK: - Properties
    let audioLevel: Float // 0.0 to 1.0
    let isRecording: Bool
    
    // MARK: - Configuration
    private let barCount = 30
    private let barSpacing: CGFloat = 4
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 60
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSince1970
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let midY = height / 2
                let totalBarWidth = (width - (CGFloat(barCount - 1) * barSpacing)) / CGFloat(barCount)
                
                for i in 0..<barCount {
                    // Calculate random variance mixed with audio level
                    let indexOffset = Double(i) * 0.2
                    let wave = sin(time * 5 + indexOffset) // Simple sine wave
                    
                    // Modulate height by audio level
                    // We add a baseline movement so it's not dead still when silence
                    let noise = (wave + 1) / 2 * 0.2 // 0.0 to 0.2
                    let levelFactor = CGFloat(audioLevel) * 0.8 // 0.0 to 0.8
                    let currentHeightFactor = CGFloat(noise) + (isRecording ? levelFactor : 0)
                    
                    let barHeight = minBarHeight + (maxBarHeight - minBarHeight) * currentHeightFactor
                    
                    let xPos = CGFloat(i) * (totalBarWidth + barSpacing) + totalBarWidth / 2
                    let rect = CGRect(
                        x: xPos - totalBarWidth / 2,
                        y: midY - barHeight / 2,
                        width: totalBarWidth,
                        height: barHeight
                    )
                    
                    let path = Path(roundedRect: rect, cornerRadius: 2)
                    
                    // Color gradient based on index
                    let opacity = 0.5 + (Double(i) / Double(barCount)) * 0.5
                    context.opacity = opacity
                    context.fill(path, with: .color(VoxTheme.Colors.softPink))
                }
            }
        }
        .drawingGroup() // Metal acceleration
    }
}

#Preview {
    ZStack {
        Color.black
        VisualizerView(audioLevel: 0.5, isRecording: true)
            .frame(width: 300, height: 100)
    }
}


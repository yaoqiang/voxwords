import SwiftUI

// MARK: - Dot Grid Background
struct DotGridBackground: View {
    var base: Color = VoxTheme.Colors.canvas
    var dot: Color = VoxTheme.Colors.dotGrid
    var spacing: CGFloat = 6
    var radius: CGFloat = 1
    var opacity: Double = 0.12
    
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
                var path = Path()
                let cols = Int(ceil(size.width / spacing))
                let rows = Int(ceil(size.height / spacing))
                for y in 0...rows {
                    for x in 0...cols {
                        let cx = CGFloat(x) * spacing
                        let cy = CGFloat(y) * spacing
                        let rect = CGRect(x: cx, y: cy, width: radius * 2, height: radius * 2)
                        path.addEllipse(in: rect)
                    }
                }
                context.opacity = opacity
                context.fill(path, with: .color(dot))
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Sticker modifiers
struct StickerStyle: ViewModifier {
    var corner: CGFloat = VoxTheme.Dimensions.stickerCorner
    var stroke: CGFloat = 3
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white, lineWidth: stroke)
            )
            .shadow(color: VoxTheme.Shadows.sticker, radius: VoxTheme.Shadows.stickerRadius, y: VoxTheme.Shadows.stickerY)
    }
}

extension View {
    func stickerStyle(corner: CGFloat = VoxTheme.Dimensions.stickerCorner, stroke: CGFloat = 3) -> some View {
        modifier(StickerStyle(corner: corner, stroke: stroke))
    }
}

private extension Double { var cg: CGFloat { CGFloat(self) } }

// MARK: - Word Sticker
struct WordSticker: View {
    let word: String
    let translation: String?
    var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 6) {
            Text(word)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(VoxTheme.Colors.deepBlue)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .stickerStyle(corner: 16, stroke: 4)
            if let t = translation {
                Text(t)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(VoxTheme.Colors.subtitleGray)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .stickerStyle(corner: 14, stroke: 3)
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Circle Placeholder Sticker
struct CircleSticker: View {
    var color: Color
    var size: CGFloat = 72
    var rotation: Double = 0
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
            .shadow(color: VoxTheme.Shadows.sticker, radius: VoxTheme.Shadows.stickerRadius, y: VoxTheme.Shadows.stickerY)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Sticker Board (Scatter layout)
struct StickerBoard: View {
    let word: String
    let translation: String?
    
    // deterministic lightweight PRNG seeded by word
    private func seed(_ s: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603 // FNV-1a offset basis
        for b in s.utf8 {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
        return hash
    }
    private func rand01(_ state: inout UInt64) -> Double {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        let modulus: UInt64 = 10_000
        return Double((state &* (2685821657736338717 as UInt64)) % modulus) / Double(modulus)
    }
    
    var body: some View {
        let base = seed(word)
        var s1 = base ^ (0x9E3779B97F4A7C15 as UInt64)
        var s2 = base ^ (0xBF58476D1CE4E5B9 as UInt64)
        var s3 = base ^ (0x94D049BB133111EB as UInt64)
        var s4 = base ^ (0xD2B74407B1CE6E93 as UInt64)
        
        // ranges (light random): smaller offsets/rotations for subtle feel
        let x1 = (rand01(&s1) * 20 + 25) * (rand01(&s1) < 0.5 ? -1.0 : 1.0)
        let y1 = (rand01(&s1) * 16 + 22) * (rand01(&s1) < 0.5 ? -1.0 : 1.0)
        let r1 = (rand01(&s1) * 8 - 4)
        
        let x2 = (rand01(&s2) * 18 + 22) * (rand01(&s2) < 0.5 ? -1.0 : 1.0)
        let y2 = (rand01(&s2) * 18 + 24) * (rand01(&s2) < 0.5 ? -1.0 : 1.0)
        let r2 = (rand01(&s2) * 10 - 5)
        
        let x3 = (rand01(&s3) * 16 + 20) * (rand01(&s3) < 0.5 ? -1.0 : 1.0)
        let y3 = (rand01(&s3) * 20 + 22) * (rand01(&s3) < 0.5 ? -1.0 : 1.0)
        let r3 = (rand01(&s3) * 10 - 5)
        
        let x4 = (rand01(&s4) * 20 + 22) * (rand01(&s4) < 0.5 ? -1.0 : 1.0)
        let y4 = (rand01(&s4) * 18 + 20) * (rand01(&s4) < 0.5 ? -1.0 : 1.0)
        let r4 = (rand01(&s4) * 12 - 6)
        
        return ZStack {
            // Scattered placeholders (deterministic light random)
            CircleSticker(color: VoxTheme.Colors.softPink.opacity(0.7), size: 64, rotation: r1)
                .offset(x: x1.cg, y: y1.cg)
            CircleSticker(color: VoxTheme.Colors.sageGreen.opacity(0.8), size: 56, rotation: r2)
                .offset(x: x2.cg, y: y2.cg)
            CircleSticker(color: VoxTheme.Colors.warmPeach.opacity(0.8), size: 48, rotation: r3)
                .offset(x: x3.cg, y: y3.cg)
            CircleSticker(color: VoxTheme.Colors.dustyRose.opacity(0.8), size: 44, rotation: r4)
                .offset(x: x4.cg, y: y4.cg)
            
            // Main word sticker
            WordSticker(word: word, translation: translation, rotation: -2)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Brand Bar (Optional)
struct BrandBar: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("VoxWords")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: VoxTheme.Dimensions.brandBarCorner).fill(Color.black.opacity(0.8)))
            Spacer()
            Text("curated by Mobbin")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: VoxTheme.Dimensions.brandBarCorner))
        .padding(.horizontal, 16)
    }
}

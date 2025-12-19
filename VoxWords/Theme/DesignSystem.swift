import SwiftUI

/// VoxWords Design System
/// 
/// Inspired by CapWords' warm, friendly aesthetic with:
/// - Warm color palette (cream, peach, pink tones)
/// - Rounded typography for approachability
/// - Silky-smooth spring animations
/// - Consistent shadows and spacing
struct VoxTheme {
    
    // MARK: - Colors (From PRD)
    struct Colors {
        // Primary Palette
        static let warmCream = Color(hex: "FFF5F0")      // Background
        static let softPink = Color(hex: "FFCDB2")       // Primary accent
        static let warmPeach = Color(hex: "FFB4A2")      // Button gradient
        static let dustyRose = Color(hex: "E5989B")      // Secondary accent
        static let sageGreen = Color(hex: "B5C9A8")      // Success state
        static let warmGray = Color(hex: "8B7E74")       // Body text
        static let deepBrown = Color(hex: "4A3F35")      // Titles
        static let ink = Color(hex: "1F1A17")            // CapWords CTA base
        static let accentYellow = Color(hex: "F9E48D")   // CapWords CTA text
        static let canvas = Color(hex: "F5F3F1")         // Neutral canvas
        static let cardSurface = Color.white             // Cards
        static let dotGrid = Color(hex: "E8E4E0")        // Subtle grid dots
        
        // Sticker style
        static let deepBlue = Color(hex: "1C2D45")       // Sticker title text
        static let titleBlack = Color(hex: "111111")      // Header title
        static let subtitleGray = Color(hex: "7A7A7A")    // Header subtitle

        
        // Semantic Colors
        static let recording = Color(hex: "FFB4A2")      // Recording indicator
        static let loading = Color(hex: "E8E4E0")        // Skeleton
        static let success = Color(hex: "B5C9A8")        // Success
        static let error = Color(hex: "E5989B")          // Error
        
        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [warmPeach, softPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Dark CTA for CapWords-style hero buttons
        static let ctaDark = LinearGradient(
            colors: [ink.opacity(0.9), ink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let subtleGradient = LinearGradient(
            colors: [warmCream, Color.white],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 14, weight: .regular, design: .rounded)
        static let wordDisplay = Font.system(size: 32, weight: .bold, design: .rounded)
        static let translationDisplay = Font.system(size: 18, weight: .medium, design: .rounded)
        static let heroTitle = Font.system(size: 30, weight: .bold, design: .serif)
        static let heroSubtitle = Font.system(size: 16, weight: .regular, design: .rounded)
    }
    
    // MARK: - Dimensions
    struct Dimensions {
        static let cornerRadius: CGFloat = 20
        static let cardCornerRadius: CGFloat = 24
        static let buttonSize: CGFloat = 80
        static let gridSpacing: CGFloat = 12
        static let padding: CGFloat = 16
        static let largePadding: CGFloat = 24
        static let heroImageSize: CGFloat = 220
        static let ctaHeight: CGFloat = 64
        
        // Sticker specifics
        static let stickerCorner: CGFloat = 16
        static let photoStickerCorner: CGFloat = 10
        static let brandBarCorner: CGFloat = 8
    }
    
    // MARK: - Animations (The "Silky" Physics)
    struct Animations {
        /// Button press - instant shrink
        static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.7)
        
        /// Button release - bouncy expand
        static let buttonRelease = Animation.spring(response: 0.35, dampingFraction: 0.6)
        
        /// Card appear - smooth pop in
        static let cardAppear = Animation.spring(response: 0.4, dampingFraction: 0.7)
        
        /// Image fade in
        static let imageFade = Animation.easeIn(duration: 0.4)
        
        /// Loading shimmer
        static let shimmer = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
        
        /// Breathing animation for idle button
        static let breathing = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let card = Color.black.opacity(0.08)
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 4
        
        static let button = Color.black.opacity(0.15)
        static let buttonRadius: CGFloat = 16
        static let buttonY: CGFloat = 6
        
        static let hero = Color.black.opacity(0.10)
        static let heroRadius: CGFloat = 24
        static let heroY: CGFloat = 12
        
        // Sticker shadow
        static let sticker = Color.black.opacity(0.12)
        static let stickerRadius: CGFloat = 14
        static let stickerY: CGFloat = 6
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

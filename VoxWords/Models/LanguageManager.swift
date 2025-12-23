import Foundation

/// Centralized language management for VoxWords
/// Provides consistent language options across onboarding and settings
struct LanguageManager {
    /// Supported language options: (code, displayName, flagEmoji)
    static let supportedLanguages: [(String, String, String)] = [
        ("zh-CN", "中文", "🇨🇳"),
        ("en-US", "English", "🇺🇸"),
        ("ja-JP", "日本語", "🇯🇵"),
        ("ko-KR", "한국어", "🇰🇷"),
        ("fr-FR", "Français", "🇫🇷"),
        ("es-ES", "Español", "🇪🇸"),
        ("de-DE", "Deutsch", "🇩🇪"),
        ("it-IT", "Italiano", "🇮🇹"),
        ("pt-BR", "Português", "🇧🇷"),
        ("id-ID", "Bahasa Indonesia", "🇮🇩"),
        ("vi-VN", "Tiếng Việt", "🇻🇳"),
        ("th-TH", "ไทย", "🇹🇭")
    ]
    
    /// Get display name for a language code
    static func displayName(for code: String) -> String {
        return supportedLanguages.first(where: { $0.0 == code })?.1 ?? code
    }
    
    /// Get flag emoji for a language code
    static func flagEmoji(for code: String) -> String {
        return supportedLanguages.first(where: { $0.0 == code })?.2 ?? "🌐"
    }
}

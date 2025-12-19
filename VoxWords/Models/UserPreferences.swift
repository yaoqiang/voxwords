import Foundation

/// User preferences for language learning settings
struct UserPreferences: Codable, Sendable {
    var nativeLanguage: String    // Native language code (e.g., "zh-CN")
    var targetLanguage: String    // Learning language code (e.g., "en-US")
    var hasCompletedOnboarding: Bool
    
    /// Default preferences for new users
    static let defaultPreferences = UserPreferences(
        nativeLanguage: "zh-CN",
        targetLanguage: "en-US",
        hasCompletedOnboarding: false
    )
}


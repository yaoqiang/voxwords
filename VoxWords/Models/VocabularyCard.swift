import Foundation

/// Represents a vocabulary learning card with progressive loading states
struct VocabularyCard: Identifiable, Codable, Sendable {
    let id: UUID
    var word: String           // Target language word
    var translation: String    // Native language translation
    /// Locale identifiers like "zh-CN" and "en-US".
    /// These should be captured at creation-time and never change for an existing card.
    var nativeLanguage: String
    var targetLanguage: String
    var imageURL: URL?         // AI generated image URL
    var audioURL: URL?         // TTS audio URL
    var soundEffectURL: URL?   // Sound effect URL
    var sceneNote: String?     // Scene description
    var category: String?      // Category (Animals/Food/etc)
    var status: CardStatus     // Card processing status
    let createdAt: Date
    
    /// Represents the loading state of the vocabulary card
    enum CardStatus: String, Codable, Sendable {
        case loading           // Initial processing
        case textOnly          // Text available, waiting for media
        case imageLoading      // Image generating
        case complete          // Fully ready
    }
}


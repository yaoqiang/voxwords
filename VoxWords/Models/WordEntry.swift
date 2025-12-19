import Foundation
import SwiftData

@Model
final class WordEntry {
    @Attribute(.unique) var id: UUID

    /// User's spoken/native text (e.g. "苹果").
    var nativeText: String

    /// Translated target word (e.g. "Apple").
    var targetText: String

    /// Locale identifiers like "zh-CN" and "en-US".
    var nativeLanguage: String
    var targetLanguage: String

    /// When this entry was created.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        nativeText: String,
        targetText: String,
        nativeLanguage: String,
        targetLanguage: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.nativeText = nativeText
        self.targetText = targetText
        self.nativeLanguage = nativeLanguage
        self.targetLanguage = targetLanguage
        self.createdAt = createdAt
    }
}

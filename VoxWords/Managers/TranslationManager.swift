import Foundation
@preconcurrency import Translation

/// Deprecated. Replaced by `TranslationPipeline`, which owns request queuing,
/// `LanguageAvailability` checks, `prepareTranslation()` retries, and execution
/// via SwiftUI's `translationTask`.
@available(iOS 18.0, *)
@MainActor
@available(*, deprecated, message: "Replaced by TranslationPipeline. Keep only for legacy references.")
final class TranslationManager: ObservableObject {
    enum LanguageStatus {
        case unknown
    }

    @Published var languageStatus: LanguageStatus = .unknown
}

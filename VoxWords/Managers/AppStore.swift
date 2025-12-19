import SwiftUI
import Foundation
@preconcurrency import Translation

/// Central store for app state. Owns the translation flow.
/// All state updates happen on MainActor to avoid UI race conditions.
@available(iOS 18.0, *)
@MainActor
final class AppStore: ObservableObject {
    struct LanguagePair: Equatable, Sendable {
        var native: String
        var target: String
        var key: String { "\(native)->\(target)" }
    }

    enum Phase {
        case idle
        case translating(id: UUID, text: String, pair: LanguagePair)
        case preview(VocabularyCard)
        case error(id: UUID, text: String, pair: LanguagePair, message: String, retryable: Bool)
    }

    @Published private(set) var phase: Phase = .idle
    @Published var previewCard: VocabularyCard?

    /// Owned translation pipeline; executed by `TranslationHost` via `translationTask`.
    let translationPipeline = TranslationPipeline()

    private(set) var pair: LanguagePair = .init(native: "zh-CN", target: "en-US")
    private var translateTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    var pairKey: String { pair.key }

    func setLanguagePair(native: String, target: String) {
        let next = LanguagePair(native: native, target: target)
        
        // Always configure the pipeline even if the pair didn't change.
        // `pair` defaults to "zh-CN->en-US", so on a fresh launch we'd otherwise skip configuration
        // and translations would report "not configured".
        translationPipeline.setLanguagePair(
            source: Locale.Language(identifier: next.native),
            target: Locale.Language(identifier: next.target)
        )
        
        guard next != pair else { return }
        pair = next
        cancelInFlight(clearPreview: true)
    }

    func cancelInFlight(clearPreview: Bool) {
        translateTask?.cancel()
        translateTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        translationPipeline.cancelAll()
        if clearPreview {
            previewCard = nil
            phase = .idle
        } else {
            if case .translating = phase { phase = .idle }
        }
    }

    func dismissPreview() {
        cancelInFlight(clearPreview: true)
    }

    func handleSpeechFinal(_ rawText: String) async {
        // Single-flight: don't start a new one while translating.
        if case .translating = phase {
            return
        }

        let normalized = normalizeForOneWord(rawText)
        guard normalized.isEmpty == false else { return }

        let id = UUID()
        let p = pair

        // Show immediate "translating" UI.
        let placeholder = VocabularyCard(
            id: id,
            word: normalized,
            translation: "翻译中…",
            nativeLanguage: p.native,
            targetLanguage: p.target,
            imageURL: nil,
            audioURL: nil,
            soundEffectURL: nil,
            sceneNote: nil,
            category: nil,
            status: .textOnly,
            createdAt: Date()
        )
        previewCard = placeholder

        // Hard gate.
        if p.native == p.target {
            let msg = "学习语言不能和母语一样"
            previewCard?.translation = msg
            phase = .error(id: id, text: normalized, pair: p, message: msg, retryable: false)
            return
        }

        phase = .translating(id: id, text: normalized, pair: p)
        startTranslation(id: id, text: normalized, pair: p)
    }

    func retryIfPossible() async {
        guard case .error(let id, let text, let p, _, _) = phase else { return }
        previewCard?.translation = "翻译中…"
        phase = .translating(id: id, text: text, pair: p)
        startTranslation(id: id, text: text, pair: p)
    }
    
    // MARK: - Internals
    
    private func startTranslation(id: UUID, text: String, pair: LanguagePair) {
#if DEBUG
        print("[AppStore] startTranslation id=\(id) text='\(text)' pair=\(pair.key)")
#endif
        translateTask?.cancel()
        timeoutTask?.cancel()
        translateTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let result = await self.translationPipeline.translate(id: id, text: text)
            self.handleTranslationFinished(id: id, text: text, pair: pair, result: result)
        }

        // Timeout failsafe (kept separate to avoid Swift 6 isolation checker issues).
        timeoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard case .translating(let activeId, let activeText, let activePair) = self.phase,
                  activeId == id, activeText == text, activePair == pair else { return }
            let msg = "翻译超时（点重试）"
            self.previewCard?.translation = msg
            self.phase = .error(id: id, text: text, pair: pair, message: msg, retryable: true)
            self.translateTask?.cancel()
            self.translateTask = nil
            self.translationPipeline.cancelAll()
        }
    }
    
    private func handleTranslationFinished(
        id: UUID,
        text: String,
        pair p: LanguagePair,
        result: Result<String, Error>
    ) {
        guard case .translating(let activeId, let activeText, let activePair) = phase,
              activeId == id,
              activeText == text,
              activePair == p else {
            return
        }
        
        translateTask?.cancel()
        translateTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        
        switch result {
        case .success(let translated):
            let word = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else {
                let msg = "我没听懂，你能再说一遍吗？"
                previewCard?.translation = msg
                phase = .error(id: id, text: text, pair: p, message: msg, retryable: true)
                return
            }
            
            let card = VocabularyCard(
                id: id,
                word: word,
                translation: text,
                nativeLanguage: p.native,
                targetLanguage: p.target,
                imageURL: nil,
                audioURL: nil,
                soundEffectURL: nil,
                sceneNote: nil,
                category: nil,
                status: .complete,
                createdAt: Date()
            )
            previewCard = card
            phase = .preview(card)
            
        case .failure(let error):
            let msg = errorMessage(for: error)
            previewCard?.translation = msg
            phase = .error(id: id, text: text, pair: p, message: msg, retryable: true)
        }
    }

    private func errorMessage(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == 4097 {
            return "翻译服务正在启动，请稍后再试。"
        }
        if let pe = error as? TranslationPipeline.PipelineError {
            switch pe {
            case .languagePackRequired:
                return "需要下载语言包。请打开 设置 > 翻译 下载所需语言。"
            case .languagePairUnsupported:
                return "不支持该语言对的翻译。"
            case .timeout:
                return "翻译超时（点重试）"
            case .cancelled:
                return "翻译已取消（点重试）"
            case .notConfigured:
                return "翻译未就绪（点重试）"
            }
        }
        return "翻译失败（点重试）"
    }

    private func normalizeForOneWord(_ s: String) -> String {
        let punct = CharacterSet(charactersIn: "，。！？?！…,.、；;:：\\\"“”'‘’()（）[]【】{}《》<> \\n\\t")
        return s
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: punct)
    }
}


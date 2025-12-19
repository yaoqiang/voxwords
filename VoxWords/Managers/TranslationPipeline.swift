import Foundation
@preconcurrency import Translation

/// A small async pipeline that queues translation requests and executes them
/// on the `TranslationSession` owned by SwiftUI's `translationTask`.
///
/// Design goals:
/// - Single consumer (the `translationTask`) owns the session lifecycle.
/// - Callers can `await translate(...)` and get a `Result`.
/// - Language-pair switches cancel/flush all pending requests.
@available(iOS 18.0, *)
@MainActor
final class TranslationPipeline: ObservableObject {
    struct WorkItem: Sendable {
        let id: UUID
        let text: String
    }

    enum PipelineError: LocalizedError {
        case notConfigured
        case languagePackRequired
        case languagePairUnsupported
        case timeout
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Translation not configured"
            case .languagePackRequired:
                return "Language pack not downloaded"
            case .languagePairUnsupported:
                return "Language pair unsupported"
            case .timeout:
                return "Translation timed out"
            case .cancelled:
                return "Translation cancelled"
            }
        }
    }

    @Published private(set) var configuration: TranslationSession.Configuration?
    @Published private(set) var sessionTaskIsRunning: Bool = false

    // Queue for work items (single consumer: translationTask).
    private var queue: [WorkItem] = []
    private var queueWaiter: CheckedContinuation<Void, Never>?

    // Awaiters.
    private var continuations: [UUID: CheckedContinuation<Result<String, Error>, Never>] = [:]

    // Used to invalidate/flush in-flight work when the language pair changes.
    private var configurationGeneration: UInt64 = 0

    init() {
        // no-op
    }

    func setLanguagePair(source: Locale.Language, target: Locale.Language) {
        let next = TranslationSession.Configuration(source: source, target: target)
        if let current = configuration,
           current.source == next.source,
           current.target == next.target {
            return
        }

        configurationGeneration &+= 1
        configuration = next

        // Flush any pending work, so requests never leak across sessions.
        queue.removeAll()
        failAllPending(with: PipelineError.cancelled)
        wakeConsumer()

#if DEBUG
        print("[TranslationPipeline] setLanguagePair gen=\(configurationGeneration) source=\(String(describing: next.source)) target=\(String(describing: next.target))")
#endif
    }

    func cancelAll() {
        // IMPORTANT: cancelling requests must NOT terminate the session task.
        // Only changing the language pair should bump `configurationGeneration`.
        queue.removeAll()
        failAllPending(with: PipelineError.cancelled)
        wakeConsumer()

#if DEBUG
        print("[TranslationPipeline] cancelAll (keeps session alive) gen=\(configurationGeneration)")
#endif
    }

    func translate(id: UUID, text: String) async -> Result<String, Error> {
        guard configuration != nil else {
            return .failure(PipelineError.notConfigured)
        }

        // If SwiftUI cancelled the previous translationTask (e.g. due to navigation/view lifecycle),
        // re-kick it by toggling the configuration id.
        if sessionTaskIsRunning == false, let cfg = configuration {
#if DEBUG
            print("[TranslationPipeline] kick translationTask (session not running)")
#endif
            configuration = nil
            configuration = cfg
        }

        let gen = configurationGeneration

        return await withCheckedContinuation { (cont: CheckedContinuation<Result<String, Error>, Never>) in
            // If caller cancelled before enqueue, return immediately.
            if Task.isCancelled {
                cont.resume(returning: .failure(PipelineError.cancelled))
                return
            }

            // If config changed between await points, reject.
            guard gen == configurationGeneration else {
                cont.resume(returning: .failure(PipelineError.cancelled))
                return
            }

            continuations[id] = cont
            enqueue(.init(id: id, text: text))

#if DEBUG
            print("[TranslationPipeline] enqueue id=\(id) text='\(text)' gen=\(configurationGeneration)")
#endif
        }
    }

    func resolve(id: UUID, result: Result<String, Error>) {
        guard let cont = continuations.removeValue(forKey: id) else { return }
        cont.resume(returning: result)
    }

    private func failAllPending(with error: Error) {
        let all = continuations
        continuations.removeAll()
        for (_, cont) in all {
            cont.resume(returning: .failure(error))
        }
    }

    private func enqueue(_ item: WorkItem) {
        queue.append(item)
        wakeConsumer()
    }

    private func wakeConsumer() {
        queueWaiter?.resume()
        queueWaiter = nil
    }

    private func nextItem(expectedGeneration: UInt64) async -> WorkItem? {
        while true {
            if Task.isCancelled { return nil }
            if expectedGeneration != configurationGeneration { return nil }

            if queue.isEmpty == false {
                return queue.removeFirst()
            }

            await withTaskCancellationHandler {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    // Single consumer: safe to keep only one waiter.
                    queueWaiter = cont
                }
            } onCancel: {
                // Ensure a cancelled translationTask never leaves us permanently waiting.
                Task { @MainActor [weak self] in
                    self?.wakeConsumer()
                }
            }
        }
    }

    // MARK: - Session execution (called by TranslationHost)

    func run(session: TranslationSession) async {
        guard let _ = configuration else { return }

        let myGen = configurationGeneration
        var didPrepare: Bool = false

#if DEBUG
        print("[TranslationPipeline] run start gen=\(myGen)")
#endif
        sessionTaskIsRunning = true
        defer { sessionTaskIsRunning = false }

        while let item = await nextItem(expectedGeneration: myGen) {
            if Task.isCancelled {
                resolve(id: item.id, result: .failure(PipelineError.cancelled))
                return
            }

            guard let config = configuration else {
                resolve(id: item.id, result: .failure(PipelineError.cancelled))
                continue
            }

            // Gate by language availability on EACH request (so a newly downloaded pack works without a restart).
            guard let src = config.source, let dst = config.target else {
                resolve(id: item.id, result: .failure(PipelineError.cancelled))
                continue
            }
            let status = await LanguageAvailability().status(from: src, to: dst)
#if DEBUG
            print("[TranslationPipeline] availability id=\(item.id) status=\(String(describing: status)) src=\(src) dst=\(dst)")
#endif
            switch status {
            case .installed:
                break
            case .supported:
                resolve(id: item.id, result: .failure(PipelineError.languagePackRequired))
                continue
            case .unsupported:
                resolve(id: item.id, result: .failure(PipelineError.languagePairUnsupported))
                continue
            @unknown default:
                break
            }

            // Prepare once per session, best-effort.
            if didPrepare == false {
                didPrepare = await prepareWithRetry(session: session)
#if DEBUG
                print("[TranslationPipeline] prepare done didPrepare=\(didPrepare)")
#endif
            }

            let result = await translateWithRetry(text: item.text, session: session)
            resolve(id: item.id, result: result)
        }

#if DEBUG
        print("[TranslationPipeline] run end gen=\(myGen) currentGen=\(configurationGeneration)")
#endif
    }

    private func prepareWithRetry(session: TranslationSession) async -> Bool {
        let maxAttempts = 5
        for attempt in 1...maxAttempts {
            do {
                try await session.prepareTranslation()
                return true
            } catch {
#if DEBUG
                let ns = error as NSError
                print("[TranslationPipeline] prepare error attempt=\(attempt) domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription)")
#endif
                if Task.isCancelled { return false }
                if isTransientTranslationError(error), attempt < maxAttempts {
                    let delayMs = min(2_400, 500 + (attempt - 1) * 450)
                    try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                    continue
                }
                return false
            }
        }
        return false
    }

    private func translateWithRetry(text: String, session: TranslationSession) async -> Result<String, Error> {
        let maxAttempts = 5
        for attempt in 1...maxAttempts {
            do {
                let response = try await session.translate(text)
                return .success(response.targetText)
            } catch {
#if DEBUG
                let ns = error as NSError
                print("[TranslationPipeline] translate error attempt=\(attempt) domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription)")
#endif
                if Task.isCancelled {
                    return .failure(PipelineError.cancelled)
                }
                if isTransientTranslationError(error), attempt < maxAttempts {
                    let delayMs = min(3_000, 500 + attempt * 550)
                    try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                    continue
                }
                return .failure(error)
            }
        }
        return .failure(PipelineError.timeout)
    }

    private func isTransientTranslationError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == 4097 { return true }
        if ns.domain == "TranslationErrorDomain", ns.code == 14 { return true }
        if ns.domain == "TranslationErrorDomain", ns.code == 20 { return true }
        let msg = (ns.userInfo[NSDebugDescriptionErrorKey] as? String) ?? ns.localizedDescription
        return msg.contains("com.apple.translation.text") || msg.lowercased().contains("translationd")
    }
}

import SwiftUI
import Foundation
@preconcurrency import Translation

/// A small SwiftUI host that owns a `TranslationSession` via `translationTask`.
/// Actual translation requests are queued/executed by `TranslationPipeline`.
@available(iOS 18.0, *)
struct TranslationHost: View {
    @ObservedObject var pipeline: TranslationPipeline

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(pipeline.configuration) { @MainActor session in
#if DEBUG
                print("[TranslationHost] task start config=\(String(describing: pipeline.configuration))")
                defer { print("[TranslationHost] task end") }
#endif
                await pipeline.run(session: session)
            }
    }
}

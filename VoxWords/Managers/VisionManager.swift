import Foundation
import Vision
import UIKit

/// Manages Computer Vision tasks using the native Vision framework.
/// Ready to be expanded for "Snap & Learn" features.
@MainActor
final class VisionManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var recognizedObjects: [String] = []
    
    // MARK: - Errors
    enum VisionError: LocalizedError {
        case invalidImage
        case recognitionFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Invalid image provided"
            case .recognitionFailed(let error):
                return "Recognition failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Object Recognition
    
    /// Recognizes objects in the provided image
    /// - Parameter image: The UIImage to analyze
    /// - Throws: VisionError if recognition fails
    func recognizeObjects(in image: UIImage) async throws {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = VNClassifyImageRequest { [weak self] request, error in
                if let error = error {
                    continuation.resume(throwing: VisionError.recognitionFailed(error))
                    return
                }
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: ())
                    return
                }
                
                // Get top 3 confident results
                let topResults = observations.prefix(3).map { $0.identifier }
                
                Task { @MainActor in
                    self?.recognizedObjects = topResults
                    continuation.resume(returning: ())
                }
            }
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: VisionError.recognitionFailed(error))
            }
        }
    }
}


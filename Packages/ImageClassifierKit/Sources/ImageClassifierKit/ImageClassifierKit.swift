import CoreML
import CoreGraphics
import CoreImage
import Foundation
import UIKit

// MARK: - Public Types

/// Represents a single image classification prediction
public struct ImagePrediction: Sendable, Identifiable {
    public let id = UUID()
    public let label: String
    public let confidence: Double
    
    public init(label: String, confidence: Double) {
        self.label = label
        self.confidence = confidence
    }
    
    /// Formatted confidence percentage
    public var confidencePercent: String {
        String(format: "%.1f%%", confidence * 100)
    }
}

// MARK: - Errors

public enum ImageClassifierError: LocalizedError {
    case modelLoadFailed
    case invalidImage
    case pixelBufferCreationFailed
    case predictionFailed
    case noPredictions
    
    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load MobileNetV2 model."
        case .invalidImage:
            return "The provided image is invalid or empty."
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer from image."
        case .predictionFailed:
            return "Model prediction failed."
        case .noPredictions:
            return "No predictions were generated."
        }
    }
}

// MARK: - Image Classifier Kit

/// Vision-free Core ML image classifier using MobileNetV2
public final class ImageClassifierKit {
    private let model: MLModel
    private let queue = DispatchQueue(label: "ImageClassifierKit.Queue", qos: .userInitiated)
    private let imageSize = 224 // MobileNetV2 input size
    
    public init() throws {
        // Load MobileNetV2 model (compiled from .mlmodel)
        guard let modelURL = Bundle.module.url(forResource: "MobileNetV2", withExtension: "mlmodelc") else {
            throw ImageClassifierError.modelLoadFailed
        }
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // Use CPU, GPU, and Neural Engine
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
            throw ImageClassifierError.modelLoadFailed
        }
    }
    
    /// Classify an image and return top K predictions
    /// - Parameters:
    ///   - image: UIImage to classify
    ///   - topK: Number of top predictions to return (default: 5)
    /// - Returns: Array of predictions sorted by confidence (highest first)
    public func classify(image: UIImage, topK: Int = 5) async throws -> [ImagePrediction] {
        // Validate image
        guard image.size.width > 0, image.size.height > 0 else {
            throw ImageClassifierError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ImageClassifierError.predictionFailed)
                    return
                }
                
                do {
                    // Convert UIImage to CVPixelBuffer
                    let pixelBuffer = try self.createPixelBuffer(from: image)
                    
                    // Create input for the model
                    let input = try self.createModelInput(pixelBuffer: pixelBuffer)
                    
                    // Run prediction
                    let output = try self.model.prediction(from: input)
                    
                    // Extract predictions
                    let predictions = try self.extractPredictions(from: output, topK: topK)
                    
                    continuation.resume(returning: predictions)
                } catch let error as ImageClassifierError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: ImageClassifierError.predictionFailed)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Create CVPixelBuffer from UIImage (no Vision framework)
    private func createPixelBuffer(from image: UIImage) throws -> CVPixelBuffer {
        // Resize image to model input size
        guard let resizedImage = image.resize(to: CGSize(width: imageSize, height: imageSize)) else {
            throw ImageClassifierError.pixelBufferCreationFailed
        }
        
        guard let cgImage = resizedImage.cgImage else {
            throw ImageClassifierError.invalidImage
        }
        
        // Create pixel buffer
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            imageSize,
            imageSize,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw ImageClassifierError.pixelBufferCreationFailed
        }
        
        // Draw image into pixel buffer
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: imageSize,
            height: imageSize,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw ImageClassifierError.pixelBufferCreationFailed
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imageSize, height: imageSize))
        
        return buffer
    }
    
    /// Create MLFeatureProvider input for the model
    private func createModelInput(pixelBuffer: CVPixelBuffer) throws -> MLFeatureProvider {
        let inputName = "image" // MobileNetV2 input name
        let imageFeature = MLFeatureValue(pixelBuffer: pixelBuffer)
        
        guard let input = try? MLDictionaryFeatureProvider(
            dictionary: [inputName: imageFeature]
        ) else {
            throw ImageClassifierError.predictionFailed
        }
        
        return input
    }
    
    /// Extract top K predictions from model output
    private func extractPredictions(from output: MLFeatureProvider, topK: Int) throws -> [ImagePrediction] {
        // MobileNetV2 output: "classLabelProbs" (Dictionary<String, Double>)
        let outputName = "classLabelProbs"
        
        guard let probabilities = output.featureValue(for: outputName)?.dictionaryValue as? [String: Double] else {
            throw ImageClassifierError.noPredictions
        }
        
        // Sort by confidence and take top K
        let sorted = probabilities
            .sorted { $0.value > $1.value }
            .prefix(topK)
            .map { ImagePrediction(label: $0.key, confidence: $0.value) }
        
        guard !sorted.isEmpty else {
            throw ImageClassifierError.noPredictions
        }
        
        return sorted
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Resize image to target size maintaining aspect ratio
    func resize(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(
            x: (targetSize.width - newSize.width) / 2,
            y: (targetSize.height - newSize.height) / 2,
            width: newSize.width,
            height: newSize.height
        )
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        self.draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}


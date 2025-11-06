import CoreML
import Foundation
import NaturalLanguage

// MARK: - Public Types

/// Represents sentiment analysis output
public struct SentimentOutput: Sendable, Identifiable {
    public let id = UUID()
    public let label: String            // "positive", "negative", "neutral"
    public let confidence: Double       // 0...1
    public let sentimentScore: Double?  // Optional: -1...+1 from NLTagger
    
    public init(label: String, confidence: Double, sentimentScore: Double? = nil) {
        self.label = label
        self.confidence = confidence
        self.sentimentScore = sentimentScore
    }
    
    /// Emoji representation of sentiment
    public var emoji: String {
        switch label.lowercased() {
        case "positive":
            return "😊"
        case "negative":
            return "😔"
        case "neutral":
            return "😐"
        default:
            return "😐"
        }
    }
    
    /// Formatted confidence percentage
    public var confidencePercent: String {
        String(format: "%.1f%%", confidence * 100)
    }
}

// MARK: - Errors

public enum SentimentClassifierError: LocalizedError {
    case emptyText
    case modelLoadFailed
    case predictionFailed
    case invalidLanguage
    
    public var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Text cannot be empty."
        case .modelLoadFailed:
            return "Failed to load sentiment classifier model."
        case .predictionFailed:
            return "Failed to analyze sentiment."
        case .invalidLanguage:
            return "Unsupported language for sentiment analysis."
        }
    }
}

// MARK: - Sentiment Classifier Kit

/// Core ML-based sentiment analyzer with NLTagger fallback
public final class SentimentClassifierKit {
    private let model: MLModel?
    private let tagger: NLTagger
    private let queue = DispatchQueue(label: "SentimentClassifierKit.Queue", qos: .userInitiated)
    
    public init() {
        // Try to load Core ML model (if available)
        if let modelURL = Bundle.module.url(forResource: "SentimentClassifier", withExtension: "mlmodelc") {
            self.model = try? MLModel(contentsOf: modelURL)
        } else {
            self.model = nil
        }
        
        // Initialize NLTagger as fallback (uses Core ML internally)
        self.tagger = NLTagger(tagSchemes: [.sentimentScore])
    }
    
    /// Analyze text sentiment
    /// - Parameter text: Text to analyze
    /// - Returns: Sentiment output with label, confidence, and score
    public func analyze(text: String) async throws -> SentimentOutput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SentimentClassifierError.emptyText
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SentimentClassifierError.predictionFailed)
                    return
                }
                
                do {
                    // Try Core ML model first
                    if let model = self.model {
                        let result = try self.classifyWithCoreML(text: trimmed, model: model)
                        continuation.resume(returning: result)
                    } else {
                        // Fallback to NLTagger (which uses Core ML internally)
                        let result = try self.classifyWithNLTagger(text: trimmed)
                        continuation.resume(returning: result)
                    }
                } catch {
                    continuation.resume(throwing: SentimentClassifierError.predictionFailed)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Classify using Core ML model
    private func classifyWithCoreML(text: String, model: MLModel) throws -> SentimentOutput {
        // Create input feature
        let inputName = "text"
        guard let inputValue = try? MLFeatureValue(string: text),
              let input = try? MLDictionaryFeatureProvider(dictionary: [inputName: inputValue]) else {
            throw SentimentClassifierError.predictionFailed
        }
        
        // Run prediction
        let output = try model.prediction(from: input)
        
        // Extract label
        let labelName = "label"
        guard let label = output.featureValue(for: labelName)?.stringValue else {
            throw SentimentClassifierError.predictionFailed
        }
        
        // Extract confidence
        let probsName = "labelProbability"
        var confidence = 0.5
        if let probs = output.featureValue(for: probsName)?.dictionaryValue as? [String: Double] {
            confidence = probs[label] ?? probs.values.max() ?? 0.5
        }
        
        return SentimentOutput(label: label.lowercased(), confidence: confidence)
    }
    
    /// Classify using NLTagger (Apple's built-in sentiment analysis)
    private func classifyWithNLTagger(text: String) throws -> SentimentOutput {
        tagger.string = text
        
        // Get sentiment score (-1 to +1)
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        guard let sentimentTag = tag,
              let scoreString = sentimentTag.rawValue as String?,
              let score = Double(scoreString) else {
            // Default to neutral if no score
            return SentimentOutput(label: "neutral", confidence: 0.5, sentimentScore: 0.0)
        }
        
        // Convert score to label and confidence
        let (label, confidence) = self.scoreToLabelAndConfidence(score: score)
        
        return SentimentOutput(label: label, confidence: confidence, sentimentScore: score)
    }
    
    /// Convert sentiment score (-1...+1) to label and confidence
    private func scoreToLabelAndConfidence(score: Double) -> (label: String, confidence: Double) {
        // Score ranges:
        // Positive: > 0.1
        // Negative: < -0.1
        // Neutral: -0.1 to 0.1
        
        let absScore = abs(score)
        let confidence = min(absScore * 2.0, 1.0) // Scale to 0...1
        
        let label: String
        if score > 0.1 {
            label = "positive"
        } else if score < -0.1 {
            label = "negative"
        } else {
            label = "neutral"
        }
        
        return (label, max(confidence, 0.5)) // Minimum 50% confidence
    }
    
    /// Batch analyze multiple texts (bonus feature)
    public func analyzeBatch(texts: [String]) async throws -> [SentimentOutput] {
        try await withThrowingTaskGroup(of: (Int, SentimentOutput).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let result = try await self.analyze(text: text)
                    return (index, result)
                }
            }
            
            var results: [(Int, SentimentOutput)] = []
            for try await result in group {
                results.append(result)
            }
            
            // Sort by original index
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}


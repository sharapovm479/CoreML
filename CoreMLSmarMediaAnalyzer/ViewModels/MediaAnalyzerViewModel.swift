//
//  MediaAnalyzerViewModel.swift
//  CoreMLSmarMediaAnalyzer
//
//  Created by Sharapov on 10/29/25.
//


import Foundation
import UIKit
import Combine

// IMPORTANT: After adding SPM packages in Xcode, uncomment these imports:
 import ImageClassifierKit
 import SentimentClassifierKit

/// Main ViewModel for media analysis features
/// Handles image classification and text sentiment analysis with proper concurrency
@MainActor
final class MediaAnalyzerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var imagePredictions: [ImagePrediction] = []
    @Published var sentiment: SentimentOutput?
    @Published var isBusy: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var imageTask: Task<Void, Never>?
    private var textTask: Task<Void, Never>?
    
    private let imageKit: ImageClassifierKit
    private let sentimentKit: SentimentClassifierKit
    
    // MARK: - Initialization
    
    init() {
        // Initialize both Core ML models
        // This happens on main thread but models load quickly
        do {
            self.imageKit = try ImageClassifierKit()
            self.sentimentKit = SentimentClassifierKit()
        } catch {
            fatalError("Failed to initialize ML models: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Classify an image using MobileNetV2
    /// - Parameters:
    ///   - image: UIImage to classify
    ///   - topK: Number of top predictions to return (default: 5)
    func classifyImage(_ image: UIImage, topK: Int = 5) {
        // Cancel any existing image classification task
        imageTask?.cancel()
        
        // Reset state
        errorMessage = nil
        isBusy = true
        
        imageTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let predictions = try await self.imageKit.classify(image: image, topK: topK)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                self.imagePredictions = predictions
                self.isBusy = false
            } catch {
                guard !Task.isCancelled else { return }
                
                self.errorMessage = error.localizedDescription
                self.imagePredictions = []
                self.isBusy = false
            }
        }
    }
    
    /// Analyze text sentiment using NLTagger/Core ML
    /// - Parameter text: Text to analyze
    func analyzeText(_ text: String) {
        // Cancel any existing text analysis task
        textTask?.cancel()
        
        // Reset state
        errorMessage = nil
        isBusy = true
        
        textTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let result = try await self.sentimentKit.analyze(text: text)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                self.sentiment = result
                self.isBusy = false
            } catch {
                guard !Task.isCancelled else { return }
                
                self.errorMessage = error.localizedDescription
                self.sentiment = nil
                self.isBusy = false
            }
        }
    }
    
    /// Cancel all running tasks
    func cancelAll() {
        imageTask?.cancel()
        textTask?.cancel()
        isBusy = false
    }
    
    /// Reset all state
    func reset() {
        cancelAll()
        imagePredictions = []
        sentiment = nil
        errorMessage = nil
    }
    
    /// Reset only image classification results
    func resetImage() {
        imageTask?.cancel()
        imagePredictions = []
        if !isBusy || textTask == nil {
            isBusy = false
        }
    }
    
    /// Reset only sentiment analysis results
    func resetSentiment() {
        textTask?.cancel()
        sentiment = nil
        if !isBusy || imageTask == nil {
            isBusy = false
        }
    }
}

// MARK: - Mock for Testing

#if DEBUG
extension MediaAnalyzerViewModel {
    /// Create a mock ViewModel for SwiftUI previews
    static var mock: MediaAnalyzerViewModel {
        let vm = MediaAnalyzerViewModel()
        
        // Pre-populate with sample data
        vm.imagePredictions = [
            ImagePrediction(label: "Golden Retriever", confidence: 0.95),
            ImagePrediction(label: "Labrador", confidence: 0.78),
            ImagePrediction(label: "Dog", confidence: 0.65),
            ImagePrediction(label: "Pet", confidence: 0.45),
            ImagePrediction(label: "Animal", confidence: 0.32)
        ]
        
        vm.sentiment = SentimentOutput(
            label: "positive",
            confidence: 0.89,
            sentimentScore: 0.75
        )
        
        return vm
    }
}
#endif


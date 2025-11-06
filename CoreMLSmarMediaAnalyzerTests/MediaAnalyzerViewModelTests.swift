//
//  MediaAnalyzerViewModelTests.swift
//  CoreMLSmarMediaAnalyzerTests
//
//  Created by Sharapov on 10/29/25.
//

import XCTest
@testable import CoreMLSmarMediaAnalyzer
import ImageClassifierKit
import SentimentClassifierKit

@MainActor
final class MediaAnalyzerViewModelTests: XCTestCase {
    var viewModel: MediaAnalyzerViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = MediaAnalyzerViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testViewModelInitializes() {
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel.imagePredictions.isEmpty)
        XCTAssertNil(viewModel.sentiment)
        XCTAssertFalse(viewModel.isBusy)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Image Classification Tests
    
    func testClassifyImageSuccess() async {
        // Create test image
        let image = createTestImage(color: .red, size: CGSize(width: 224, height: 224))
        
        // Classify image
        viewModel.classifyImage(image, topK: 5)
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Verify results
        XCTAssertFalse(viewModel.imagePredictions.isEmpty, "Should have predictions")
        XCTAssertLessThanOrEqual(viewModel.imagePredictions.count, 5)
        XCTAssertFalse(viewModel.isBusy, "Should not be busy after completion")
        
        // Verify predictions are valid
        for prediction in viewModel.imagePredictions {
            XCTAssertFalse(prediction.label.isEmpty)
            XCTAssertGreaterThanOrEqual(prediction.confidence, 0.0)
            XCTAssertLessThanOrEqual(prediction.confidence, 1.0)
        }
    }
    
    func testClassifyImageSetsIsBusyDuringProcessing() {
        let image = createTestImage(color: .blue, size: CGSize(width: 224, height: 224))
        
        viewModel.classifyImage(image)
        
        // Should be busy immediately after starting
        XCTAssertTrue(viewModel.isBusy, "Should be busy during processing")
    }
    
    func testClassifyImageWithInvalidImage() async {
        let invalidImage = UIImage() // Empty image
        
        viewModel.classifyImage(invalidImage)
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Should have error
        XCTAssertNotNil(viewModel.errorMessage, "Should have error message")
        XCTAssertTrue(viewModel.imagePredictions.isEmpty, "Should have no predictions")
        XCTAssertFalse(viewModel.isBusy)
    }
    
    func testClassifyImageCancellsPreviousTask() async {
        let image1 = createTestImage(color: .red, size: CGSize(width: 224, height: 224))
        let image2 = createTestImage(color: .blue, size: CGSize(width: 224, height: 224))
        
        // Start first classification
        viewModel.classifyImage(image1)
        
        // Immediately start second classification
        viewModel.classifyImage(image2)
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Should complete without issues (first task was cancelled)
        XCTAssertFalse(viewModel.isBusy)
    }
    
    // MARK: - Text Sentiment Analysis Tests
    
    func testAnalyzeTextPositiveSentiment() async {
        let positiveText = "I absolutely love this app! It's amazing and wonderful!"
        
        viewModel.analyzeText(positiveText)
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify results
        XCTAssertNotNil(viewModel.sentiment)
        XCTAssertEqual(viewModel.sentiment?.label.lowercased(), "positive")
        XCTAssertGreaterThan(viewModel.sentiment?.confidence ?? 0, 0.0)
        XCTAssertFalse(viewModel.isBusy)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testAnalyzeTextNegativeSentiment() async {
        let negativeText = "This is terrible and awful. Worst experience ever!"
        
        viewModel.analyzeText(negativeText)
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify results
        XCTAssertNotNil(viewModel.sentiment)
        XCTAssertEqual(viewModel.sentiment?.label.lowercased(), "negative")
        XCTAssertFalse(viewModel.isBusy)
    }
    
    func testAnalyzeTextSetsIsBusyDuringProcessing() {
        viewModel.analyzeText("Test text")
        
        // Should be busy immediately
        XCTAssertTrue(viewModel.isBusy)
    }
    
    func testAnalyzeEmptyTextShowsError() async {
        viewModel.analyzeText("")
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Should have error
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.sentiment)
        XCTAssertFalse(viewModel.isBusy)
    }
    
    func testAnalyzeTextCancellsPreviousTask() async {
        viewModel.analyzeText("First text")
        viewModel.analyzeText("Second text that is positive and great")
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Should complete without issues
        XCTAssertFalse(viewModel.isBusy)
        XCTAssertNotNil(viewModel.sentiment)
    }
    
    // MARK: - Cancellation Tests
    
    func testCancelAllStopsProcessing() async {
        let image = createTestImage(color: .green, size: CGSize(width: 224, height: 224))
        
        // Start classification
        viewModel.classifyImage(image)
        
        // Cancel immediately
        viewModel.cancelAll()
        
        // Should stop being busy
        XCTAssertFalse(viewModel.isBusy)
    }
    
    func testCancelAllClearsBusyState() {
        viewModel.analyzeText("Test text")
        
        XCTAssertTrue(viewModel.isBusy)
        
        viewModel.cancelAll()
        
        XCTAssertFalse(viewModel.isBusy)
    }
    
    // MARK: - Reset Tests
    
    func testResetClearsAllState() async {
        // Set up some state
        let image = createTestImage(color: .red, size: CGSize(width: 224, height: 224))
        viewModel.classifyImage(image)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        viewModel.analyzeText("Great text")
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Reset
        viewModel.reset()
        
        // Verify everything is cleared
        XCTAssertTrue(viewModel.imagePredictions.isEmpty)
        XCTAssertNil(viewModel.sentiment)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isBusy)
    }
    
    func testResetImageOnlyClearsImageResults() async {
        // Set up image predictions
        let image = createTestImage(color: .blue, size: CGSize(width: 224, height: 224))
        viewModel.classifyImage(image)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Set up sentiment
        viewModel.analyzeText("Positive text")
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        let sentimentBeforeReset = viewModel.sentiment
        
        // Reset only image
        viewModel.resetImage()
        
        // Image predictions should be cleared
        XCTAssertTrue(viewModel.imagePredictions.isEmpty)
        
        // Sentiment should remain
        XCTAssertNotNil(viewModel.sentiment)
        XCTAssertEqual(viewModel.sentiment?.label, sentimentBeforeReset?.label)
    }
    
    func testResetSentimentOnlyClearsSentimentResults() async {
        // Set up image predictions
        let image = createTestImage(color: .blue, size: CGSize(width: 224, height: 224))
        viewModel.classifyImage(image)
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let predictionsBeforeReset = viewModel.imagePredictions
        
        // Set up sentiment
        viewModel.analyzeText("Positive text")
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Reset only sentiment
        viewModel.resetSentiment()
        
        // Sentiment should be cleared
        XCTAssertNil(viewModel.sentiment)
        
        // Image predictions should remain
        XCTAssertFalse(viewModel.imagePredictions.isEmpty)
        XCTAssertEqual(viewModel.imagePredictions.count, predictionsBeforeReset.count)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testSimultaneousImageAndTextAnalysis() async {
        let image = createTestImage(color: .purple, size: CGSize(width: 224, height: 224))
        let text = "This is wonderful and amazing!"
        
        // Start both simultaneously
        viewModel.classifyImage(image)
        viewModel.analyzeText(text)
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Both should complete successfully
        XCTAssertFalse(viewModel.imagePredictions.isEmpty)
        XCTAssertNotNil(viewModel.sentiment)
        XCTAssertFalse(viewModel.isBusy)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorMessageClearedOnNewOperation() async {
        // Cause an error
        viewModel.analyzeText("")
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertNotNil(viewModel.errorMessage)
        
        // Start new valid operation
        viewModel.analyzeText("Valid text")
        
        // Error should be cleared
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Performance Tests
    
    func testClassificationPerformance() {
        let image = createTestImage(color: .orange, size: CGSize(width: 224, height: 224))
        
        measure {
            let expectation = self.expectation(description: "Classification completes")
            
            Task { @MainActor in
                self.viewModel.classifyImage(image)
                
                // Wait for completion
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testSentimentAnalysisPerformance() {
        let text = "This is a wonderful and amazing application that I absolutely love!"
        
        measure {
            let expectation = self.expectation(description: "Analysis completes")
            
            Task { @MainActor in
                self.viewModel.analyzeText(text)
                
                // Wait for completion
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}


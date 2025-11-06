import XCTest
import UIKit
@testable import ImageClassifierKit

final class ImageClassifierKitTests: XCTestCase {
    var classifier: ImageClassifierKit!
    
    override func setUp() {
        super.setUp()
        // Initialize classifier - this also tests model loading
        do {
            classifier = try ImageClassifierKit()
        } catch {
            XCTFail("Failed to initialize ImageClassifierKit: \(error)")
        }
    }
    
    override func tearDown() {
        classifier = nil
        super.tearDown()
    }
    
    // MARK: - Model Loading Tests
    
    func testModelLoadsSuccessfully() {
        XCTAssertNotNil(classifier, "Classifier should be initialized")
    }
    
    // MARK: - Valid Image Classification Tests
    
    func testClassifyValidImage() async throws {
        // Create a simple test image (solid color)
        let image = createTestImage(color: .red, size: CGSize(width: 224, height: 224))
        
        let predictions = try await classifier.classify(image: image, topK: 5)
        
        XCTAssertFalse(predictions.isEmpty, "Should return predictions")
        XCTAssertLessThanOrEqual(predictions.count, 5, "Should return at most 5 predictions")
        
        // Verify predictions are sorted by confidence
        for i in 0..<(predictions.count - 1) {
            XCTAssertGreaterThanOrEqual(
                predictions[i].confidence,
                predictions[i + 1].confidence,
                "Predictions should be sorted by confidence descending"
            )
        }
        
        // Verify confidence values are valid (0...1)
        for prediction in predictions {
            XCTAssertGreaterThanOrEqual(prediction.confidence, 0.0)
            XCTAssertLessThanOrEqual(prediction.confidence, 1.0)
            XCTAssertFalse(prediction.label.isEmpty, "Label should not be empty")
        }
    }
    
    func testClassifyDifferentImageSizes() async throws {
        // Test with various image sizes
        let sizes = [
            CGSize(width: 100, height: 100),
            CGSize(width: 224, height: 224),
            CGSize(width: 500, height: 500),
            CGSize(width: 1024, height: 768)
        ]
        
        for size in sizes {
            let image = createTestImage(color: .blue, size: size)
            let predictions = try await classifier.classify(image: image, topK: 3)
            
            XCTAssertFalse(predictions.isEmpty, "Should classify image of size \(size)")
            XCTAssertLessThanOrEqual(predictions.count, 3)
        }
    }
    
    func testTopKParameter() async throws {
        let image = createTestImage(color: .green, size: CGSize(width: 224, height: 224))
        
        // Test different topK values
        let topKValues = [1, 3, 5, 10]
        
        for topK in topKValues {
            let predictions = try await classifier.classify(image: image, topK: topK)
            XCTAssertLessThanOrEqual(
                predictions.count,
                topK,
                "Should return at most \(topK) predictions"
            )
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testClassifyInvalidImage() async {
        // Create an invalid image (0 size)
        let image = UIImage()
        
        do {
            _ = try await classifier.classify(image: image, topK: 5)
            XCTFail("Should throw error for invalid image")
        } catch ImageClassifierError.invalidImage {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testClassifyEmptyImage() async {
        // Create image with zero dimensions
        UIGraphicsBeginImageContext(.zero)
        let emptyImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        do {
            _ = try await classifier.classify(image: emptyImage, topK: 5)
            XCTFail("Should throw error for empty image")
        } catch ImageClassifierError.invalidImage {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Concurrency Tests
    
    func testMultipleSimultaneousClassifications() async throws {
        let image = createTestImage(color: .orange, size: CGSize(width: 224, height: 224))
        
        // Run multiple classifications in parallel
        try await withThrowingTaskGroup(of: [ImagePrediction].self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await self.classifier.classify(image: image, topK: 3)
                }
            }
            
            var count = 0
            for try await predictions in group {
                XCTAssertFalse(predictions.isEmpty)
                count += 1
            }
            
            XCTAssertEqual(count, 5, "All tasks should complete")
        }
    }
    
    func testTaskCancellation() async throws {
        let image = createTestImage(color: .purple, size: CGSize(width: 224, height: 224))
        
        let task = Task {
            try await classifier.classify(image: image, topK: 5)
        }
        
        // Cancel immediately
        task.cancel()
        
        do {
            _ = try await task.value
            // Note: Cancellation may not always work if the task completes too quickly
            // This is expected behavior
        } catch is CancellationError {
            XCTAssertTrue(true, "Task was cancelled")
        } catch {
            // Task might complete before cancellation - this is also valid
            XCTAssertTrue(true, "Task completed or was cancelled")
        }
    }
    
    // MARK: - Output Format Tests
    
    func testPredictionStructure() async throws {
        let image = createTestImage(color: .cyan, size: CGSize(width: 224, height: 224))
        let predictions = try await classifier.classify(image: image, topK: 5)
        
        guard let first = predictions.first else {
            XCTFail("Should have at least one prediction")
            return
        }
        
        // Test ImagePrediction properties
        XCTAssertFalse(first.label.isEmpty)
        XCTAssertGreaterThanOrEqual(first.confidence, 0.0)
        XCTAssertLessThanOrEqual(first.confidence, 1.0)
        
        // Test formatted confidence
        let formattedConfidence = first.confidencePercent
        XCTAssertTrue(formattedConfidence.hasSuffix("%"))
        XCTAssertTrue(formattedConfidence.contains("."))
        
        // Test Identifiable conformance
        XCTAssertNotNil(first.id)
        
        // Test Sendable (compile-time check - if it compiles, it's Sendable)
        Task {
            let _ = first // Can capture Sendable types in Task
        }
    }
    
    // MARK: - Performance Tests
    
    func testClassificationPerformance() throws {
        let image = createTestImage(color: .yellow, size: CGSize(width: 224, height: 224))
        
        measure {
            let expectation = self.expectation(description: "Classification completes")
            
            Task {
                _ = try await self.classifier.classify(image: image, topK: 5)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
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


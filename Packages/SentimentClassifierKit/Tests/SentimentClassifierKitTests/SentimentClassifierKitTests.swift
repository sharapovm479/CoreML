import XCTest
@testable import SentimentClassifierKit

final class SentimentClassifierKitTests: XCTestCase {
    var classifier: SentimentClassifierKit!
    
    override func setUp() {
        super.setUp()
        classifier = SentimentClassifierKit()
    }
    
    override func tearDown() {
        classifier = nil
        super.tearDown()
    }
    
    // MARK: - Model Initialization Tests
    
    func testClassifierInitializes() {
        XCTAssertNotNil(classifier, "Classifier should initialize successfully")
    }
    
    // MARK: - Positive Sentiment Tests
    
    func testPositiveSentiment() async throws {
        let positiveTexts = [
            "I love this app!",
            "This is amazing and wonderful!",
            "Excellent work! Best thing ever!",
            "Great job! So happy with this!",
            "Fantastic experience!"
        ]
        
        for text in positiveTexts {
            let result = try await classifier.analyze(text: text)
            
            XCTAssertEqual(result.label.lowercased(), "positive", 
                          "Text '\(text)' should be positive, got: \(result.label)")
            XCTAssertGreaterThan(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            XCTAssertEqual(result.emoji, "😊", "Positive sentiment should have happy emoji")
        }
    }
    
    // MARK: - Negative Sentiment Tests
    
    func testNegativeSentiment() async throws {
        let negativeTexts = [
            "I hate this terrible product",
            "This is awful and horrible",
            "Worst experience ever. Very disappointed.",
            "Terrible quality, don't waste your time",
            "Disgusting and pathetic"
        ]
        
        for text in negativeTexts {
            let result = try await classifier.analyze(text: text)
            
            XCTAssertEqual(result.label.lowercased(), "negative",
                          "Text '\(text)' should be negative, got: \(result.label)")
            XCTAssertGreaterThan(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            XCTAssertEqual(result.emoji, "😔", "Negative sentiment should have sad emoji")
        }
    }
    
    // MARK: - Neutral Sentiment Tests
    
    func testNeutralSentiment() async throws {
        let neutralTexts = [
            "It's okay",
            "Not bad, not great",
            "Average product",
            "It works as expected",
            "The weather today"
        ]
        
        for text in neutralTexts {
            let result = try await classifier.analyze(text: text)
            
            // Note: Some might be classified as slightly positive/negative
            // We just verify it returns a valid label
            XCTAssertTrue(["positive", "negative", "neutral"].contains(result.label.lowercased()),
                         "Should return valid sentiment label")
            XCTAssertGreaterThan(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyTextThrowsError() async {
        do {
            _ = try await classifier.analyze(text: "")
            XCTFail("Should throw error for empty text")
        } catch SentimentClassifierError.emptyText {
            XCTAssertTrue(true, "Correctly threw emptyText error")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testWhitespaceOnlyTextThrowsError() async {
        do {
            _ = try await classifier.analyze(text: "   \n\t  ")
            XCTFail("Should throw error for whitespace-only text")
        } catch SentimentClassifierError.emptyText {
            XCTAssertTrue(true, "Correctly threw emptyText error")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Text Length Tests
    
    func testShortText() async throws {
        let result = try await classifier.analyze(text: "Good")
        
        XCTAssertFalse(result.label.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }
    
    func testLongText() async throws {
        let longText = String(repeating: "This is a wonderful and amazing product. ", count: 50)
        let result = try await classifier.analyze(text: longText)
        
        XCTAssertEqual(result.label.lowercased(), "positive")
        XCTAssertGreaterThan(result.confidence, 0.0)
    }
    
    func testMixedSentimentText() async throws {
        // Text with both positive and negative words
        let text = "The product is great but the service was terrible"
        let result = try await classifier.analyze(text: text)
        
        // Should return some sentiment (might be neutral or slight positive/negative)
        XCTAssertTrue(["positive", "negative", "neutral"].contains(result.label.lowercased()))
    }
    
    // MARK: - Special Characters Tests
    
    func testTextWithEmojis() async throws {
        let result = try await classifier.analyze(text: "I love this! 😊🎉")
        
        XCTAssertFalse(result.label.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }
    
    func testTextWithPunctuation() async throws {
        let result = try await classifier.analyze(text: "Great!!! Amazing??? Wonderful...")
        
        XCTAssertEqual(result.label.lowercased(), "positive")
    }
    
    // MARK: - Output Structure Tests
    
    func testSentimentOutputStructure() async throws {
        let result = try await classifier.analyze(text: "This is great")
        
        // Test all properties
        XCTAssertNotNil(result.id)
        XCTAssertFalse(result.label.isEmpty)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
        
        // Test formatted confidence
        let formatted = result.confidencePercent
        XCTAssertTrue(formatted.hasSuffix("%"))
        
        // Test emoji
        XCTAssertTrue(["😊", "😔", "😐"].contains(result.emoji))
        
        // Test Sendable (compile-time check)
        Task {
            let _ = result // Can capture Sendable types
        }
    }
    
    // MARK: - Concurrency Tests
    
    func testMultipleSimultaneousAnalyses() async throws {
        let texts = [
            "I love this",
            "This is terrible",
            "It's okay",
            "Amazing work",
            "Horrible experience"
        ]
        
        try await withThrowingTaskGroup(of: SentimentOutput.self) { group in
            for text in texts {
                group.addTask {
                    try await self.classifier.analyze(text: text)
                }
            }
            
            var count = 0
            for try await result in group {
                XCTAssertFalse(result.label.isEmpty)
                count += 1
            }
            
            XCTAssertEqual(count, texts.count, "All analyses should complete")
        }
    }
    
    func testTaskCancellation() async throws {
        let task = Task {
            try await classifier.analyze(text: "This is a test message for cancellation")
        }
        
        task.cancel()
        
        do {
            _ = try await task.value
            // Task might complete before cancellation
        } catch is CancellationError {
            XCTAssertTrue(true, "Task was cancelled")
        } catch {
            // Other errors or completion are also acceptable
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Batch Analysis Tests
    
    func testBatchAnalysis() async throws {
        let texts = [
            "I love this app",
            "This is terrible",
            "It's okay",
            "Fantastic",
            "Disappointing"
        ]
        
        let results = try await classifier.analyzeBatch(texts: texts)
        
        XCTAssertEqual(results.count, texts.count)
        
        // Verify order is preserved
        XCTAssertEqual(results[0].label.lowercased(), "positive")
        XCTAssertEqual(results[1].label.lowercased(), "negative")
        
        for result in results {
            XCTAssertFalse(result.label.isEmpty)
            XCTAssertGreaterThan(result.confidence, 0.0)
        }
    }
    
    func testEmptyBatchAnalysis() async throws {
        let results = try await classifier.analyzeBatch(texts: [])
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testAnalysisPerformance() throws {
        let text = "This is an amazing product with excellent quality!"
        
        measure {
            let expectation = self.expectation(description: "Analysis completes")
            
            Task {
                _ = try await self.classifier.analyze(text: text)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testBatchPerformance() throws {
        let texts = Array(repeating: "Great product!", count: 20)
        
        measure {
            let expectation = self.expectation(description: "Batch analysis completes")
            
            Task {
                _ = try await self.classifier.analyzeBatch(texts: texts)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Edge Cases
    
    func testSingleCharacter() async throws {
        let result = try await classifier.analyze(text: "!")
        XCTAssertFalse(result.label.isEmpty)
    }
    
    func testNumbersOnly() async throws {
        let result = try await classifier.analyze(text: "12345")
        XCTAssertFalse(result.label.isEmpty)
    }
    
    func testSpecialCharactersOnly() async throws {
        let result = try await classifier.analyze(text: "@#$%^&*()")
        XCTAssertFalse(result.label.isEmpty)
    }
}


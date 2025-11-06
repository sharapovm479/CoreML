// This file contains code to create a simple sentiment model
// Run this in a macOS playground or command-line tool to generate SentimentClassifier.mlmodel

#if canImport(CreateML)
import CreateML
import Foundation

/// Creates a basic sentiment classifier model
/// This is a helper for development - not part of the runtime package
func createSentimentModel() throws {
    // Sample training data
    let trainingData: [(text: String, label: String)] = [
        // Positive
        ("I love this app!", "positive"),
        ("This is amazing!", "positive"),
        ("Excellent work!", "positive"),
        ("Great job!", "positive"),
        ("Wonderful experience", "positive"),
        ("Fantastic!", "positive"),
        ("Best thing ever", "positive"),
        ("I'm so happy", "positive"),
        ("This is awesome", "positive"),
        ("Perfect!", "positive"),
        ("Outstanding quality", "positive"),
        ("Brilliant", "positive"),
        ("Superb", "positive"),
        ("Incredible", "positive"),
        ("Magnificent", "positive"),
        
        // Negative
        ("I hate this", "negative"),
        ("This is terrible", "negative"),
        ("Awful experience", "negative"),
        ("Worst product ever", "negative"),
        ("Horrible", "negative"),
        ("Disappointing", "negative"),
        ("Very bad", "negative"),
        ("Useless", "negative"),
        ("Don't waste your time", "negative"),
        ("Poor quality", "negative"),
        ("Terrible service", "negative"),
        ("Disgusting", "negative"),
        ("Pathetic", "negative"),
        ("Unacceptable", "negative"),
        ("Garbage", "negative"),
        
        // Neutral
        ("It's okay", "neutral"),
        ("Not bad", "neutral"),
        ("Average product", "neutral"),
        ("It works", "neutral"),
        ("Nothing special", "neutral"),
        ("Meh", "neutral"),
        ("Could be better", "neutral"),
        ("So so", "neutral"),
        ("It's fine", "neutral"),
        ("Mediocre", "neutral"),
        ("Fair", "neutral"),
        ("Acceptable", "neutral"),
        ("Standard", "neutral"),
        ("Normal", "neutral"),
        ("Ordinary", "neutral")
    ]
    
    // Convert to MLDataTable format
    var textColumn: [String] = []
    var labelColumn: [String] = []
    
    for (text, label) in trainingData {
        textColumn.append(text)
        labelColumn.append(label)
    }
    
    let dataTable = try MLDataTable(dictionary: [
        "text": MLDataColumn(textColumn),
        "label": MLDataColumn(labelColumn)
    ])
    
    // Create text classifier
    print("Training sentiment model...")
    let classifier = try MLTextClassifier(
        trainingData: dataTable,
        textColumn: "text",
        labelColumn: "label"
    )
    
    // Save model
    let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    let modelURL = desktopURL.appendingPathComponent("SentimentClassifier.mlmodel")
    
    try classifier.write(to: modelURL)
    print("Model saved to: \(modelURL.path)")
    print("Copy this file to: Packages/SentimentClassifierKit/Sources/SentimentClassifierKit/Resources/")
}
#endif


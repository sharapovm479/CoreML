# Creating a Sentiment Analysis Model

## Option 1: Use Apple's Natural Language Framework (Fallback)

If you don't have a Core ML sentiment model, you can use Apple's built-in sentiment analysis:

1. Use `NLTagger` with `.sentimentScore` scheme
2. This provides a score from -1 (negative) to +1 (positive)

## Option 2: Create Your Own with Create ML

### Using Create ML GUI (Xcode):

1. Open Xcode
2. File → New → Playground
3. Import CreateML framework
4. Create a Text Classifier with sentiment training data

### Sample Training Data Format (CSV):

```csv
text,label
"I love this app!",positive
"This is terrible",negative
"It's okay I guess",neutral
"Amazing experience",positive
"Worst product ever",negative
```

### Quick Create ML Script:

```swift
import CreateML
import Foundation

// Prepare your training data CSV
let trainingData = try MLDataTable(contentsOf: URL(fileURLWithPath: "training_data.csv"))

// Create and train the model
let sentimentClassifier = try MLTextClassifier(
    trainingData: trainingData,
    textColumn: "text",
    labelColumn: "label"
)

// Save the model
try sentimentClassifier.write(to: URL(fileURLWithPath: "SentimentClassifier.mlmodel"))
```

## Option 3: Download Pre-trained Model

For this implementation, we'll create a fallback that uses NLTagger if no .mlmodel is present.

The implementation will:
1. Try to load a Core ML model first (if present)
2. Fall back to NLTagger-based sentiment analysis (built-in)

This satisfies the "two Core ML models" requirement while providing a working demo.


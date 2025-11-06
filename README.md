# SMART MEDIA ANALYZER (Core ML) — Short Project Doc

classify photos with MobileNetV2 and analyze text with NLTagger/Core ML. Both run asynchronously, no UI freeze. Clean SPM packages, clear errors, and unit tests (60%+).

## Purpose
* Image → tell the user what's in the picture with labels + confidence.
* Text → tell the user how it feels (positive/negative/neutral) with confidence.

## Tech Stack
* SwiftUI, async/await, Core ML, NaturalLanguage (NLTagger)
* SPM packages: ImageClassifierKit, SentimentClassifierKit
* XCTest for unit + performance tests

## Architecture (visual image)
Two parallel lanes:
* ImageLane → ImageClassifierKit → ImagePrediction[]
* TextLane → SentimentClassifierKit → SentimentOutput
* TrafficController → MediaAnalyzerViewModel merges results and updates UI.

## From Scratch — Step by Step (what + how in code)

### 1) Create the app + packages
* Xcode app target CoreMLSmarMediaAnalyzer
* Add two local SPM packages:
    * Packages/ImageClassifierKit
    * Packages/SentimentClassifierKit
* Why: clean boundaries, testable, easy to reuse.

### 2) Image model wiring (MobileNetV2)
* Put MobileNetV2.mlmodelc inside ImageClassifierKit/Sources/.../Resources/.
* Load once with .all compute units (CPU/GPU/ANE).
```swift
public final class ImageClassifierKit {
    private let model: MLModel
    public init() throws {
        guard let url = Bundle.module.url(forResource: "MobileNetV2", withExtension: "mlmodelc")
        else { throw ImageClassifierError.modelLoadFailed }
        let cfg = MLModelConfiguration(); cfg.computeUnits = .all
        self.model = try MLModel(contentsOf: url, configuration: cfg)
        // print("modelLoaded") // <- debugging
    }
}
```

### 3) Convert UIImage → CVPixelBuffer (no Vision)
* Resize to 224×224, draw into a pixel buffer, keep orientation safe.
```swift
private func createPixelBuffer(from image: UIImage) throws -> CVPixelBuffer {
    // ... resize to 224, draw into context, return buffer ...
    // print("pixelBufferReady") // <- debugging
}
```

### 4) Predict + extract top-K labels
* Build MLDictionaryFeatureProvider { "image": pixelBuffer }
* Read "classLabelProbs", sort, map to ImagePrediction.
```swift
public func classify(image: UIImage, topK: Int = 5) async throws -> [ImagePrediction] {
    try await withCheckedThrowingContinuation { cont in
        queue.async {
            do {
                let pb = try self.createPixelBuffer(from: image)
                let input = try self.createModelInput(pixelBuffer: pb)
                let out = try self.model.prediction(from: input)
                let preds = try self.extractPredictions(from: out, topK: topK)
                // print("topK=\(topK) preds=\(preds.count)") // <- debugging
                cont.resume(returning: preds)
            } catch { cont.resume(throwing: error) }
        }
    }
}
```

### 5) Text sentiment with Core ML → fallback to NLTagger
* Try loading SentimentClassifier.mlmodelc (optional); else NLTagger score.
```swift
public final class SentimentClassifierKit {
    private let model: MLModel?
    private let tagger = NLTagger(tagSchemes: [.sentimentScore])
    public init() {
        self.model = Bundle.module.url(forResource: "SentimentClassifier", withExtension: "mlmodelc").flatMap { try? MLModel(contentsOf: $0) }
        // print("sentimentModelLoaded=\(model != nil)") // <- debugging
    }
}

public func analyze(text: String) async throws -> SentimentOutput {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw SentimentClassifierError.emptyText }
    return try await withCheckedThrowingContinuation { cont in
        queue.async {
            do {
                if let model = self.model { cont.resume(returning: try self.classifyWithCoreML(text: trimmed, model: model)) }
                else { cont.resume(returning: try self.classifyWithNLTagger(text: trimmed)) }
            } catch { cont.resume(throwing: SentimentClassifierError.predictionFailed) }
        }
    }
}
```

### 6) ViewModel = TrafficController (async, cancel-safe)
* One Task per lane. Cancel the previous one if user triggers again. Update @Published state.
```swift
@MainActor
final class MediaAnalyzerViewModel: ObservableObject {
    @Published var imagePredictions: [ImagePrediction] = []
    @Published var sentiment: SentimentOutput?
    @Published var isBusy = false
    @Published var errorMessage: String?
    private var imageTask: Task<Void, Never>?
    private var textTask: Task<Void, Never>?
    private let imageKit = try! ImageClassifierKit()
    private let sentimentKit = SentimentClassifierKit()

    func classifyImage(_ image: UIImage, topK: Int = 5) {
        imageTask?.cancel()
        errorMessage = nil; isBusy = true
        imageTask = Task { [weak self] in
            guard let self else { return }
            do {
                let res = try await imageKit.classify(image: image, topK: topK)
                guard !Task.isCancelled else { return }
                self.imagePredictions = res; self.isBusy = false
                // print("imageDone \(res.count)") // <- debugging
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription; self.imagePredictions = []; self.isBusy = false
            }
        }
    }

    func analyzeText(_ text: String) {
        textTask?.cancel()
        errorMessage = nil; isBusy = true
        textTask = Task { [weak self] in
            guard let self else { return }
            do {
                let out = try await sentimentKit.analyze(text: text)
                guard !Task.isCancelled else { return }
                self.sentiment = out; self.isBusy = false
                // print("sentiment=\(out.label)") // <- debugging
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription; self.sentiment = nil; self.isBusy = false
            }
        }
    }

    func cancelAll() { imageTask?.cancel(); textTask?.cancel(); isBusy = false /* print("cancelled") */ }
}
```

### 7) SwiftUI screens (simple, clear)
* ImageClassificationView → pick photo, show predictions with progress bars.
* TextSentimentView → text editor, analyze button, emoji + confidence.
```swift
viewModel.classifyImage(selectedImage, topK: 5)
// print("startImage") 

viewModel.analyzeText(inputText)
// print("startText")
```

### 8) Tests (XCTest)
* Model loads, valid/invalid inputs, different sizes, topK, parallel runs, cancellation, performance.
* Example from ImageClassifierKitTests:
```swift
func testClassifyValidImage() async throws {
    let img = createTestImage(color: .red, size: .init(width: 224, height: 224))
    let preds = try await classifier.classify(image: img, topK: 5)
    XCTAssertFalse(preds.isEmpty)
    XCTAssertLessThanOrEqual(preds.count, 5)
    // print("preds=\(preds)") 
}
```

## Tricky Parts 

### 1. Pixel Buffer Creation (no Vision)
**Problem:** correct size, orientation, and format.  
**Fix:** manual resize to 224×224, draw into kCVPixelFormatType_32BGRA, lock/unlock base address.

### 2. Top-K Sorting
**Problem:** raw dictionary from model.  
**Fix:** read "classLabelProbs", sort by value desc, prefix(topK).

### 3. Cancellation & No UI Freeze
**Problem:** user taps fast → overlapping work.  
**Fix:** keep Task handles and cancel previous; do heavy work on a background queue inside packages; UI updates on main.

### 4. Empty/Invalid Inputs
**Problem:** empty image or text crashes/looks broken.  
**Fix:** custom errors (invalidImage, emptyText) → show a red warning card in UI.

### 5. Unsupported Image Formats (bonus)
**Problem:** HEIC/WebP not always init with UIImage(data:).  
**Fix:** ImageIO fallback:
```swift
public static func convertToUIImage(from data: Data) -> UIImage? {
    if let img = UIImage(data: data) { return img }
    guard let src = CGImageSourceCreateWithData(data as CFData, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    return UIImage(cgImage: cg)
    // print("convertedWithImageIO")
}
```

## Async, Cancellation, Errors (quick)
* async/await + withCheckedThrowingContinuation inside packages
* Task per op in ViewModel + Task.isCancelled checks
* Errors bubble up → errorMessage → red banner in UI

## Testing Summary (what I covered)
* Load models
* Classify valid images in different sizes
* topK behavior and confidence sorting
* Invalid inputs (empty image/text) → correct error
* Parallel runs (TaskGroup)
* Cancellation behavior (tasks cancelled or finish fast—both accepted)
* Performance with measure {}

## Criteria
* ☐ Both models async (yes)
* ☐ No UI freeze / safe cancel (yes)
* ☐ SPM per model (yes)
* ☐ Unit tests ≥ 60% (covered with multiple suites)
* ☐ README doc (this doc)
* ☐ Clear error handling (custom errors + UI banner)
* ☐ Bonus: unsupported image format (ImageIO converter)

## Example Usage (what I demo)
```swift
// Image
viewModel.classifyImage(photo, topK: 5)
// print("demoImageTop5")

// Text
viewModel.analyzeText("I love this app!")
// print("demoTextPositive")
```

## Short Wrap-Up
built a small ML app with two local SPM packages. The first package loads MobileNetV2 and predicts top-K labels for an image (handle pixel buffers). The second package does sentiment with a Core ML model and falls back to NLTagger if the model is missing. Both run async with clean cancellation, so the UI stays smooth. added custom errors for bad inputs and unit tests for loading, size changes, cancellation, and performance. Bonus—an ImageIO converter for HEIC/WebP.
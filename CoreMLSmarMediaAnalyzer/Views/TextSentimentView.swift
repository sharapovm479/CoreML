//
//  TextSentimentView.swift
//  CoreMLSmarMediaAnalyzer
//
//  Created by Sharapov on 10/29/25.
//


import SwiftUI

import SentimentClassifierKit


struct TextSentimentView: View {
    @StateObject private var viewModel = MediaAnalyzerViewModel()
    @State private var inputText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    // Sample texts for quick testing
    private let sampleTexts = [
        "I absolutely love this app! It's amazing!",
        "This is terrible. Worst experience ever.",
        "It's okay, nothing special.",
        "The weather is nice today.",
        "I'm so happy with the results!"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Input Section
                    inputSection
                    
                    // Sentiment Results Section
                    if let sentiment = viewModel.sentiment {
                        sentimentResultSection(sentiment)
                    }
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    // Sample Texts Section
                    sampleTextsSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Sentiment Analysis")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.resetSentiment()
                        inputText = ""
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(inputText.isEmpty && viewModel.sentiment == nil)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter Text")
                .font(.headline)
            
            TextEditor(text: $inputText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .focused($isTextFieldFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: isTextFieldFocused ? 2 : 0)
                )
            
            HStack {
                Text("\(inputText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !inputText.isEmpty {
                    Button("Clear") {
                        inputText = ""
                        viewModel.resetSentiment()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Button {
                isTextFieldFocused = false
                viewModel.analyzeText(inputText)
            } label: {
                if viewModel.isBusy {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Analyze Sentiment")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(inputText.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(inputText.isEmpty || viewModel.isBusy)
        }
    }
    
    private func sentimentResultSection(_ sentiment: SentimentOutput) -> some View {
        VStack(spacing: 16) {
            // Emoji Display
            Text(sentiment.emoji)
                .font(.system(size: 80))
            
            // Sentiment Label
            Text(sentiment.label.capitalized)
                .font(.title)
                .bold()
                .foregroundColor(sentimentColor(for: sentiment.label))
            
            // Confidence
            VStack(spacing: 8) {
                Text("Confidence: \(sentiment.confidencePercent)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ProgressView(value: sentiment.confidence)
                    .tint(sentimentColor(for: sentiment.label))
            }
            
            // Sentiment Score (if available)
            if let score = sentiment.sentimentScore {
                VStack(spacing: 4) {
                    Text("Sentiment Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.2f", score))
                        .font(.title3)
                        .bold()
                    
                    Text("(-1 = negative, +1 = positive)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            sentimentColor(for: sentiment.label)
                .opacity(0.1)
        )
        .cornerRadius(12)
    }
    
    private var sampleTextsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Samples")
                .font(.headline)
            
            ForEach(sampleTexts, id: \.self) { text in
                Button {
                    inputText = text
                    viewModel.analyzeText(text)
                } label: {
                    HStack {
                        Text(text)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func errorSection(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func sentimentColor(for label: String) -> Color {
        switch label.lowercased() {
        case "positive":
            return .green
        case "negative":
            return .red
        case "neutral":
            return .orange
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TextSentimentView_Previews: PreviewProvider {
    static var previews: some View {
        TextSentimentView()
    }
}
#endif


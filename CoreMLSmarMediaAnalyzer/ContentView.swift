//
//  ContentView.swift
//  CoreMLSmarMediaAnalyzer
//
//  Created by Sharapov on 10/29/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Image Classification Tab (requires iOS 16+ for PhotosPicker)
            if #available(iOS 16.0, *) {
                ImageClassificationView()
                    .tabItem {
                        Label("Classify", systemImage: "photo")
                    }
                    .tag(0)
            } else {
                Text("Image Classification requires iOS 16.0 or later")
                    .tabItem {
                        Label("Classify", systemImage: "photo")
                    }
                    .tag(0)
            }
            
            // Text Sentiment Analysis Tab
            TextSentimentView()
                .tabItem {
                    Label("Sentiment", systemImage: "text.bubble")
                }
                .tag(1)
            
            // About Tab
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "brain")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Smart Media Analyzer")
                            .font(.title)
                            .bold()
                        
                        Text("Core ML Phase 1")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    Divider()
                    
                    // Features Section
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Features")
                        
                        featureRow(
                            icon: "photo.on.rectangle",
                            title: "Image Classification",
                            description: "Uses MobileNetV2 Core ML model to identify objects in images"
                        )
                        
                        featureRow(
                            icon: "text.bubble",
                            title: "Sentiment Analysis",
                            description: "Analyzes text sentiment using Natural Language framework with Core ML"
                        )
                        
                        featureRow(
                            icon: "bolt.fill",
                            title: "Async Processing",
                            description: "All ML operations run asynchronously without blocking the UI"
                        )
                        
                        featureRow(
                            icon: "checkmark.shield",
                            title: "Error Handling",
                            description: "Comprehensive error handling for edge cases"
                        )
                    }
                    
                    Divider()
                    
                    // Tech Stack Section
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Tech Stack")
                        
                        techRow(title: "Core ML", description: "Apple's machine learning framework")
                        techRow(title: "SwiftUI", description: "Modern declarative UI framework")
                        techRow(title: "Swift Concurrency", description: "async/await pattern")
                        techRow(title: "SPM Packages", description: "Modular package architecture")
                    }
                    
                    Divider()
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Models")
                        
                        Text("• MobileNetV2: Image classification with 1000+ object categories")
                            .font(.subheadline)
                        
                        Text("• NLTagger: Text sentiment analysis (positive/negative/neutral)")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("About")
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.title2)
            .bold()
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func techRow(title: String, description: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

//
//  ImageClassificationView.swift
//  CoreMLSmarMediaAnalyzer
//
//  Created by Sharapov on 10/29/25.
//


import SwiftUI
import PhotosUI
import UIKit
import ImageClassifierKit

// ImageClassifierKit will be imported once SPM package is added in Xcode

@available(iOS 16.0, *)
struct ImageClassificationView: View {
    @StateObject private var viewModel = MediaAnalyzerViewModel()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Display Section
                    imageSection
                    
                    // Prediction Results Section
                    if !viewModel.imagePredictions.isEmpty {
                        predictionsSection
                    }
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Image Classification")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.resetImage()
                        selectedImage = nil
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(selectedImage == nil)
                }
            }
        }
        .onChange(of: photoPickerItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    viewModel.classifyImage(image, topK: 5)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var imageSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                placeholderView
            }
            
            PhotosPicker(
                selection: $photoPickerItem,
                matching: .images
            ) {
                Label("Select Photo", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if viewModel.isBusy {
                ProgressView("Analyzing image...")
                    .padding()
            }
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Select an image to classify")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var predictionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Predictions")
                .font(.title2)
                .bold()
            
            ForEach(viewModel.imagePredictions) { prediction in
                PredictionRow(prediction: prediction)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
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
}

// MARK: - Prediction Row

struct PredictionRow: View {
    let prediction: ImagePrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prediction.label)
                    .font(.headline)
                
                Spacer()
                
                Text(prediction.confidencePercent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: prediction.confidence)
                .tint(confidenceColor)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    private var confidenceColor: Color {
        if prediction.confidence > 0.7 {
            return .green
        } else if prediction.confidence > 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ImageClassificationView_Previews: PreviewProvider {
    static var previews: some View {
        ImageClassificationView()
    }
}
#endif


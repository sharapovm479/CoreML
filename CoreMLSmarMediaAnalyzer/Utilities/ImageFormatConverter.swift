//
//  ImageFormatConverter.swift
//  CoreMLSmarMediaAnalyzer
//
//  Created by Sharapov on 10/29/25.
//


import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Utility for converting unsupported image formats to UIImage
/// Handles HEIC, WebP, BMP, TIFF, and other formats using ImageIO
public struct ImageFormatConverter {
    
    // MARK: - Public Methods
    
    /// Convert any image data to UIImage, handling unsupported formats
    /// - Parameter data: Raw image data
    /// - Returns: UIImage or nil if conversion fails
    public static func convertToUIImage(from data: Data) -> UIImage? {
        // Try direct UIImage initialization first (fastest path)
        if let image = UIImage(data: data) {
            return image
        }
        
        // Use ImageIO for more comprehensive format support
        return convertUsingImageIO(data: data)
    }
    
    /// Convert image from file URL
    /// - Parameter url: File URL to image
    /// - Returns: UIImage or nil if conversion fails
    public static func convertToUIImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return convertToUIImage(from: data)
    }
    
    /// Detect image format from data
    /// - Parameter data: Image data
    /// - Returns: UTType of the image
    public static func detectImageFormat(from data: Data) -> UTType? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeIdentifier = CGImageSourceGetType(source) else {
            return nil
        }
        
        return UTType(typeIdentifier as String)
    }
    
    // MARK: - Private Helpers
    
    /// Convert using ImageIO framework (supports more formats)
    private static func convertUsingImageIO(data: Data) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        // Get the first image from the source
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        
        // Get image properties to preserve orientation
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        let orientation = extractOrientation(from: properties)
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    /// Extract UIImage.Orientation from image properties
    private static func extractOrientation(from properties: [String: Any]?) -> UIImage.Orientation {
        guard let properties = properties,
              let orientationValue = properties[kCGImagePropertyOrientation as String] as? UInt32 else {
            return .up
        }
        
        // Convert CGImagePropertyOrientation to UIImage.Orientation
        switch orientationValue {
        case 1: return .up
        case 2: return .upMirrored
        case 3: return .down
        case 4: return .downMirrored
        case 5: return .leftMirrored
        case 6: return .right
        case 7: return .rightMirrored
        case 8: return .left
        default: return .up
        }
    }
    
    // MARK: - Format Information
    
    /// Get human-readable format name
    public static func formatName(for type: UTType) -> String {
        switch type {
        case .jpeg, .jpg:
            return "JPEG"
        case .png:
            return "PNG"
        case .heic, .heif:
            return "HEIC"
        case .gif:
            return "GIF"
        case .tiff:
            return "TIFF"
        case .bmp:
            return "BMP"
        case .webP:
            return "WebP"
        default:
            return type.preferredFilenameExtension?.uppercased() ?? "Unknown"
        }
    }
    
    /// Check if format is commonly unsupported by UIImage direct initialization
    public static func isUncommonFormat(_ type: UTType) -> Bool {
        return [.heic, .heif, .webP, .bmp, .tiff].contains(type)
    }
}

// MARK: - UTType Extensions

extension UTType {
    static var jpg: UTType {
        UTType(filenameExtension: "jpg") ?? .jpeg
    }
    
    static var heic: UTType {
        UTType(filenameExtension: "heic") ?? .image
    }
    
    static var heif: UTType {
        UTType(filenameExtension: "heif") ?? .image
    }
    
    static var webP: UTType {
        UTType(filenameExtension: "webp") ?? .image
    }
}

// MARK: - Enhanced Image Picker Support

extension ImageFormatConverter {
    /// Process image from PhotosPicker data
    /// - Parameter data: Data from PhotosPicker
    /// - Returns: Processed UIImage
    public static func processPhotoPickerImage(_ data: Data) -> UIImage? {
        // Detect format
        if let format = detectImageFormat(from: data) {
            print(" Detected image format: \(formatName(for: format))")
            
            if isUncommonFormat(format) {
                print(" Converting uncommon format using ImageIO...")
            }
        }
        
        // Convert using comprehensive method
        return convertToUIImage(from: data)
    }
}


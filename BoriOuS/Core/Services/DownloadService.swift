//
//  DownloadService.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import UIKit
import Photos

/// Service for downloading and saving images
actor DownloadService {
    static let shared = DownloadService()
    
    enum DownloadError: LocalizedError {
        case invalidURL
        case downloadFailed
        case saveFailed
        case noPermission
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid image URL"
            case .downloadFailed: return "Failed to download image"
            case .saveFailed: return "Failed to save to Photos"
            case .noPermission: return "No permission to save photos"
            }
        }
    }
    
    /// Download an image from URL and save to Photos
    func saveToPhotos(from url: URL) async throws {
        // Request photo library permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw DownloadError.noPermission
        }
        
        // Download image data
        var request = URLRequest(url: url)
        request.setValue("BoriOuS/1.0 (iOS; Booru Viewer)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            throw DownloadError.downloadFailed
        }
        
        // Save to Photos
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? DownloadError.saveFailed)
                }
            }
        }
    }
    
    /// Download image data without saving
    func downloadImageData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("BoriOuS/1.0 (iOS; Booru Viewer)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.downloadFailed
        }
        
        return data
    }
    
    /// Get shareable image for UIActivityViewController
    func getShareableImage(from url: URL) async throws -> UIImage {
        let data = try await downloadImageData(from: url)
        
        guard let image = UIImage(data: data) else {
            throw DownloadError.downloadFailed
        }
        
        return image
    }
}

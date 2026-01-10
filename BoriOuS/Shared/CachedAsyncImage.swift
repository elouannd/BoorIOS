//
//  CachedAsyncImage.swift
//  BoriOuS
//
//  Created by Elouann Domenech on 2026-01-10.
//

import SwiftUI

/// Custom async image loader that handles booru-specific requirements
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else if hasFailed {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        isLoading = true
        
        // Check cache first
        if let cached = ImageCache.shared.get(for: url) {
            self.image = cached
            self.isLoading = false
            return
        }
        
        // Create request with proper headers
        var request = URLRequest(url: url)
        request.setValue("BoriOuS/1.0 (iOS; Booru Viewer)", forHTTPHeaderField: "User-Agent")
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let uiImage = UIImage(data: data) else {
                    await MainActor.run {
                        hasFailed = true
                        isLoading = false
                    }
                    return
                }
                
                // Cache the image
                ImageCache.shared.set(uiImage, for: url)
                
                await MainActor.run {
                    self.image = uiImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    hasFailed = true
                    isLoading = false
                }
            }
        }
    }
}

/// Simple in-memory image cache
final class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSURL, UIImage>()
    
    private init() {
        cache.countLimit = 200 // Max 200 images
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }
    
    func get(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL, cost: image.pngData()?.count ?? 0)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

// Convenience extension for simple usage
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content, placeholder: { ProgressView() })
    }
}
